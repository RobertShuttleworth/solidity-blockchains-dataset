// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import "./contracts_HandlesGSN.sol";
import "./contracts_SharedTypes.sol";
import "./lib_OpenZeppelin_access_Ownable.sol";
import "./lib_OpenZeppelin_token_ERC20_IERC20.sol";
import "./lib_OpenZeppelin_token_ERC20_utils_SafeERC20.sol";
import "./lib_OpenZeppelin_proxy_Clones.sol";
import "./lib_OpenGSN_contracts_ERC2771Recipient.sol";
import "./contracts_IGigabitEscrowOrder.sol";
import "./contracts_IGigabitEscrowStatistics.sol";
import "./contracts_IGigabitEscrowPaymaster.sol";

/**
 @dev GigabitEscrowManager contract

 This contract is used to create new escrow contracts.

 The EscrowManager contract is the owner of the GigabitEscrowOrder contracts and is 
 responsible for creating new escrow contracts by cloning the GigabitEscrowOrder 
 implementation contract. It is also responsible for keeping track of the order id 
 to escrow contract address (and vice-versa) mappings.

 note: 1) Must first launch the GigabitEscrowStatistics contract.
 
       2) Must also launch the GigabitEscrowOrder contract as an implementation
          and set the implementation address in this contract.

       3) Ideally, set the fee recipient address in this contract from the
          deployer address to a multisig wallet.

       4) For security reasons, the owner should be a multisig wallet.
*/
contract GigabitEscrowManager is Ownable, ERC2771Recipient {
    using Clones for address;
    using SafeERC20 for IERC20;

    function _msgSender() internal view override(Context, ERC2771Recipient) returns (address) {
        return ERC2771Recipient._msgSender();
    }

    function _msgData() internal view override(Context, ERC2771Recipient) returns (bytes calldata) {
        return ERC2771Recipient._msgData();
    }

    IGigabitEscrowStatistics public statistics;
    IGigabitEscrowOrder public implementation;
    IGigabitEscrowPaymaster public paymaster;
    address public feeRecipient;
    uint8 public customerTimeoutDays = 7; // number of days of customer inactivity before a worker can claim funds for submitted work
    uint8 public maxStartByDays = 30;
    uint8 public maxPayByDays = 3;
    uint8 public maxCompanyPercentageCut = 20;
    uint8 public maxDaysToComplete = 90;
    uint8 public maxRevisions = 5;
    uint8 public maxExtensions = 5;
    uint8 public minRotationIntervalDays = 1; // minimum time in days between key rotations
    bool public escrowCreationPause;   // pauses escrow creation
    bool public statisticsPause;  // pauses work status counters
    bool public rotationPause; // pauses key rotation

    mapping(address registeredStableToken => uint8 decimals) public registeredStableTokenMap;
    mapping(address authorized => uint256 timestamp) public authorizedMap;
    mapping(address escrow => string orderId) private escrowToOrderId;
    mapping(SharedTypes.WorkStatus => mapping(SharedTypes.WorkStatus => bool)) public validTransitions; // Valid state transitions

    uint8 private constant COMPANY_PERCENTAGE_CUT_CEILING = 35;
    uint8 private constant MAX_DAYS_TO_COMPLETE_CEILING = 180;
    uint8 private constant MAX_REVISIONS_CEILING = 10;
    uint8 private constant MAX_EXTENSIONS_CEILING = 10;
    uint8 private constant MAX_INPUT_ARRAY_BOUNDS = 20;

    event EscrowCreated(
        bytes32 indexed orderIdHash,
        string orderId,
        address indexed newEscrowAddress
    );
    event SetImplementation(address indexed implementation);
    event SetFeeRecipient(address indexed feeRecipient);
    event SetMaxStartByDays(uint8 maxStartByDays);
    event SetMaxPayByDays(uint8 maxPayByDays);
    event SetMaxCompanyPercentageCut(uint8 maxCompanyPercentageCut);
    event SetMaxDaysToComplete(uint8 maxDaysToComplete);
    event SetMaxRevisions(uint8 maxRevisions);
    event SetMaxExtensions(uint8 maxExtensions);
    event EscrowCreationPause(bool _value);
    event StatisticsPause(bool _value);
    event RotationPause(bool _value);
    event CounterDecrementWarning();
    event ModifiedWorkStatusCounter(
        SharedTypes.WorkStatus indexed workStatus,
        uint64 oldCounter,
        uint64 newCounter
    );
    event ReportedInOrder(
        address indexed reporter,
        address indexed reported,
        string orderId
    );
    event Rotation(address indexed oldAddress, address newAddress);
    event AddedAuthorized(address indexed);
    event RemovedAuthorized(address indexed);

    error Unauthorized();
    error UnauthorizedEOA();
    error UnregisteredClone();
    error UnauthorizedClone();
    error EscrowCreationPaused();
    error ZeroAddress();
    error ZeroValue();
    error EmptyString();
    error NoChange();
    error AddressesNotUnique();
    error StableTokenNotRegistered();
    error StableTokenAlreadyRegistered();
    error StableTokenCannotBeEOA();
    error CannotBeThisAddress();
    error ImplementationNotSet();
    error ImplementationCloneFailure();
    error ImplementationHasInvalidInit();
    error ImplementationInvalidPredictedAddress();
    error StartByDateInPast();
    error StartByDateExceedsMax();
    error CompanyPercentageCutExceedsMax();
    error OrderIdAlreadyMapped();
    error OrderIdInvalid();
    error NoOldWorkStatusToDecrement();
    error Underflow();
    error Overflow();
    error MaxStartByDaysExceedsMax();
    error MaxPayByDaysExceedsMax();
    error MaxCompanyPercentageCutExceedsMax();
    error MaxDaysToCompleteExceedsMax();
    error MaxRevisionsExceedsMax();
    error MaxExtensionsExceedsMax();
    error CannotBeOwner();
    error CannotReportYourself();
    error RotationPaused();
    error RotationTooSoon();
    error InsufficientFundsAtPredictedAddress();
    error PredictedAddressAlreadyTaken();
    error ReporterCooldown();
    error ReporterNotFound();
    error ReportedNotFound();
    error UserBlacklisted();

    /**
     * @dev Checks if the caller is registered as an escrow contract
     *      clone created by this contract
     */
    modifier onlyAuthorizedClone() {
        
        // Set up in-memory reads from storage
        address _caller = _msgSender();

        // Caller must be a contract
        if (_isEOA(_caller) == true) {
            revert UnauthorizedEOA();
        }

        // Clone must have been cloned by this contract
        if (bytes(escrowToOrderId[_caller]).length == 0) {
            revert UnregisteredClone();
        }

        // Caller must be clone of the implementation contract
        string memory _orderId = escrowToOrderId[_caller];
        bytes32 _orderIdHash = keccak256(abi.encodePacked(_orderId));

        address _predictedEscrowAddress = address(implementation).predictDeterministicAddress(_orderIdHash, address(this));
        if (_caller != _predictedEscrowAddress) {
            revert UnauthorizedClone();
        }
        _;
    }

    /**
     * @dev Checks if the caller is authorized to generate escrow contracts,
     *      the contract does not have escrow creation paused, and that the
     *      implementation contract address is set.
     */
    modifier canGenerateEscrow() {
        // Set up in-memory reads from storage
        address _caller = _msgSender();
        address _owner = owner();
        address _implementationAddress = address(implementation);
        bool _escrowCreationPause = escrowCreationPause;

        // Check if the implementation contract address is set
        if (_implementationAddress == address(0)) {
            revert ImplementationNotSet();
        }

        // If escrow creation is paused, we don't allow escrow creation
        if (_escrowCreationPause == true) {
            revert EscrowCreationPaused();
        }

        // Only an address in the authorized map OR the owner can generate escrow contracts
        if (authorizedMap[_caller] == 0 
            && _caller != _owner
        ) {
            revert Unauthorized();
        }
        _;
    }

    /**
     * @dev Constructor function
     */
    constructor(
        address _stableToken,
        uint8 _stableTokenDecimals,
        address _gigabitEscrowStatistics,
        address _gigabitEscrowOrderImplementation,
        address _paymaster,
        address _forwarder
    ) {
        setFeeRecipient(_msgSender()); // for now, set the deployer address as the fee recipient
        registerStableToken(_stableToken, _stableTokenDecimals); // polygon usdc
        statistics = IGigabitEscrowStatistics(_gigabitEscrowStatistics); // statistics contract
        if (statistics.owner() == _msgSender()) {
            statistics.addManagerToWhitelist(address(this)); // add this contract as a manager
        }
        paymaster = IGigabitEscrowPaymaster(_paymaster); // paymaster contract
        if (paymaster.owner() == _msgSender()) {
            paymaster.addManager(address(this)); // add this contract as a manager
        }
        _setTrustedForwarder(_forwarder);
        _initializeTransitions(); // Initialize the valid state transitions
        _setImplementation(_gigabitEscrowOrderImplementation); // Set the implementation contract address
    }

    /**
     * @dev Registers a stable token address, allowing it to be used in escrow contracts
     *
     * @param _newStableToken The new stable token address
     */
    function registerStableToken(address _newStableToken, uint8 _decimals) public onlyOwner {

        //////////////
        /// CHECKS ///
        //////////////

        if (_newStableToken == address(0)) {
            revert ZeroAddress();
        }

        if (_decimals == 0) {
            revert ZeroValue();
        }

        if (isRegisteredStableToken(_newStableToken) == true) {
            revert StableTokenAlreadyRegistered();
        }

        if (_isEOA(_newStableToken) == true) {
            revert StableTokenCannotBeEOA();
        }

        ///////////////
        /// EFFECTS ///
        ///////////////

        // Add stable token with decimals to mapping
        registeredStableTokenMap[_newStableToken] = _decimals;
    }

    /**
     * @dev Sets the fee recipient address
     *
     * @param _newFeeRecipient The new fee recipient address
     */
    function setFeeRecipient(address _newFeeRecipient) public onlyOwner {
        
        // Set up in-memory reads from storage
        address _oldFeeRecipient = feeRecipient;

        //////////////
        /// CHECKS ///
        //////////////

        if (_newFeeRecipient == address(0)) {
            revert ZeroAddress();
        }

        if (_newFeeRecipient == address(this)) {
            revert CannotBeThisAddress();
        }

        if (_newFeeRecipient == _oldFeeRecipient) {
            revert NoChange();
        }

        ///////////////
        /// EFFECTS ///
        ///////////////

        feeRecipient = _newFeeRecipient;

        emit SetFeeRecipient(_newFeeRecipient);
    }

    /**
     * @dev Creates a new clone of the escrow master copy contract, initializes it, and
     *      creates the necessary mappings and statistics
     *
     * @param _params The input parameters, structured as an EscrowParams struct
     */
    function createEscrow(SharedTypes.EscrowParams calldata _params) external canGenerateEscrow {

        validateCreateEscrowInput(_params);

        ///////////////
        /// EFFECTS ///
        ///////////////

        // Scope: Predict the location of the new clone of the implementation contract
        address _newEscrowAddress;
        {
            // Interpret values from input array indices
            string memory _orderId = _params.strings[0];
            
            // Predict the address of the new escrow contract
            bytes32 _orderIdHash = keccak256(abi.encodePacked(_orderId));
            address _predictedEscrowAddress = address(implementation).predictDeterministicAddress(_orderIdHash, address(this));
  
            // Verify that there's no bytecode at the predicted address
            if (_predictedEscrowAddress.code.length > 0) {
                revert PredictedAddressAlreadyTaken();
            }

            // Ensure the amount due and the service fee are present at the predicted escrow address
            address _stableToken = _params.addresses[0];
            uint256 _amountDue = _params.uint256s[0];
            uint256 _serviceFee = _params.uint256s[1];
            if (IERC20(_stableToken).balanceOf(_predictedEscrowAddress) < _amountDue + _serviceFee) {
                revert InsufficientFundsAtPredictedAddress();
            }

            _newEscrowAddress = address(implementation).cloneDeterministic(_orderIdHash);

            if (_newEscrowAddress != _predictedEscrowAddress) {
                revert ImplementationInvalidPredictedAddress();
            }

            // Map the new escrow contract address to the order id
            escrowToOrderId[_newEscrowAddress] = _orderId;

            // Ensure the clone was created successfully
            if (_newEscrowAddress == address(0)) {
                revert ImplementationCloneFailure();
            }

            emit EscrowCreated(_orderIdHash, _orderId, _newEscrowAddress);
        }

        ////////////////////
        /// INTERACTIONS ///
        ////////////////////

        // Initialize the new escrow contract with the input parameters
        try
            IGigabitEscrowOrder(_newEscrowAddress).__init__(_params)
        {} catch Error(string memory _reason) {
            // handle requires
            revert(_reason);
        } catch Panic(uint256 _errorCode) {
            // handle panics
            revert(string(abi.encodePacked("Panic error code: ", _errorCode)));
        } catch (bytes memory _error) {
            // handle custom errors
            assembly {
                revert(add(0x20, _error), mload(_error))
            }
        }

        // Scope: Perform post-creation incrementing of counters
        {
            // Trigger the statistics contract to increment the appropriate counters
            if (statisticsPause == false) {
                address _customer = _params.addresses[1];
                address _worker = _params.addresses[2];
                statistics.orderInitiated(_customer, _worker);
            }
        }

        // Scope: Whitelist escrow on paymaster
        {
            //Set the newly created escrow contracts as whitelisted for the paymaster
            IGigabitEscrowPaymaster(paymaster).whitelistEscrow(_newEscrowAddress);
        }
    }

    /**
     * @dev Validates the input for the createEscrow() function
     *
     * @param _params The input parameters for the createEscrow() function
     */
    function validateCreateEscrowInput(SharedTypes.EscrowParams calldata _params) internal view {
        // Ensure that the input arrays meet the minimum length requirements
        if (
            _params.addresses.length < 5 ||
            _params.uint256s.length < 2 ||
            _params.uint64s.length < 1 ||
            _params.uint8s.length < 6 ||
            _params.strings.length < 1 ||
            _params.bools.length < 1
        ) {
            revert("Input array missing required elements");
        }

        // Ensures against unbounded array input
        if (_params.addresses.length > MAX_INPUT_ARRAY_BOUNDS ||
            _params.uint256s.length > MAX_INPUT_ARRAY_BOUNDS ||
            _params.uint64s.length > MAX_INPUT_ARRAY_BOUNDS ||
            _params.uint8s.length > MAX_INPUT_ARRAY_BOUNDS ||
            _params.strings.length > MAX_INPUT_ARRAY_BOUNDS ||
            _params.bools.length > MAX_INPUT_ARRAY_BOUNDS
        ) {
            revert("Input array exceeds bounds");
        }

        // Scope 1: Handle Addresses
        {
            address _stableToken = _params.addresses[0];
            address _customer = _params.addresses[1];
            address _worker = _params.addresses[2];

            // Ensure the addresses are not 0x0
            if (_stableToken == address(0) ||
                _customer == address(0) ||
                _worker == address(0)
            ) {
                revert ZeroAddress();
            }

            // Ensure the addresses are unique
            if (_stableToken == _customer ||
                _stableToken == _worker ||
                _customer == _worker
            ) {
                revert AddressesNotUnique();
            }

            // Ensure the stable token is registered
            if (registeredStableTokenMap[_stableToken] == 0) {
                revert StableTokenNotRegistered();
            }

        }

        // Scope 2: Handle Uint256s
        {
            uint256 _amountDue = _params.uint256s[0];

            // Ensure the amount due is greater than 0
            if (_amountDue == 0) {
                revert ZeroValue();
            }
        }

        // Scope 3: Handle Uint64s
        {
            uint64 _startByDate = _params.uint64s[0];

            // Ensure the start by date is in the future
            if (_startByDate < block.timestamp) {
                revert StartByDateInPast();
            }

            // Ensure the start by date is not too far in the future
            if (_startByDate > block.timestamp + (maxStartByDays * 1 days)) {
                revert StartByDateExceedsMax();
            }
        }

        // Scope 4: Handle Uint8s
        {
            uint _companyPercentageCut = _params.uint8s[0];

            // Ensure the company percentage cut is greater than 0
            if (_companyPercentageCut == 0) {
                revert ZeroValue();
            }

            // Ensure the company percentage cut is not too high
            if (_companyPercentageCut > COMPANY_PERCENTAGE_CUT_CEILING) {
                revert CompanyPercentageCutExceedsMax();
            }
        }

        // Scope 5: Handle Strings
        {
            string memory _orderId = _params.strings[0];

            // Ensure the order id is not empty
            if (bytes(_orderId).length == 0) {
                revert EmptyString();
            }

            // Ensure the order id is not already mapped to an escrow contract
            if (getEscrowByOrderId(_orderId) != address(0)) {
                revert OrderIdAlreadyMapped();
            }
        }
    }

    /**
     * @dev Updates the work status counters, only callable by an escrow contract
     *
     * @dev This should still work even if the escrow contract is paused, as we don't want to
     *      block resolution of existing escrow contracts, even if we're not generating new ones
     *
     * @param _oldWorkStatus The old work status
     * @param _newWorkStatus The new work status
     */
    function updateStatusStatistics(
        SharedTypes.WorkStatus _oldWorkStatus,
        SharedTypes.WorkStatus _newWorkStatus
    ) external onlyAuthorizedClone {
        if (statisticsPause == false) {
            statistics.updateStatus(uint8(_oldWorkStatus), uint8(_newWorkStatus));
        }
    }

    function increaseWorkerFaultCount(address _worker) external onlyAuthorizedClone {
        if (statisticsPause == false) {
            statistics.incrementFaultsReceivedAsWorker(_worker);
        }
    }

    function increaseCustomerFaultCount(address _customer) external onlyAuthorizedClone {
        if (statisticsPause == false) {
            statistics.incrementFaultsReceivedAsCustomer(_customer);
        }
    }

    /**
     * @dev Checks if a stable token is registered
     *
     * @param _stableToken The stable token address
     * @return bool TRUE if the stable token is registered, FALSE otherwise
     */
    function isRegisteredStableToken(address _stableToken) public view returns (bool) {
        if (registeredStableTokenMap[_stableToken] == 0) {
            return false;
        } 
        return true;
    }

    /**
     * @dev Gets the escrow contract address for a given order id, zero address if not found
     *
     * @param _orderId The order id
     * @return address The escrow contract address
     */
    function getEscrowByOrderId(string memory _orderId) public view returns (address) {
        bytes32 _orderIdHash = keccak256(abi.encodePacked(_orderId));
        address _predictedEscrow = address(implementation).predictDeterministicAddress(_orderIdHash, address(this));
        bytes32 _registeredOrderIdHash = keccak256(abi.encodePacked(escrowToOrderId[_predictedEscrow]));

        // If the order id hash matches the registered order id hash, return the predicted escrow address
        if (_registeredOrderIdHash == _orderIdHash) {
            return _predictedEscrow;
        }

        // Otherwise, return the 0x0 address to indicate no match
        return address(0);
    }

    /**
     * @dev Gets the predicted escrow contract address for a given order id
     *
     * @param _orderId The order id
     * @return address The predicted escrow contract address
     */
    function getPredictedEscrowByOrderId(string memory _orderId) public view returns (address) {
        bytes32 _orderIdHash = keccak256(abi.encodePacked(_orderId));
        return address(implementation).predictDeterministicAddress(_orderIdHash, address(this));
    }

    /**
     * @dev Gets the order id for a given escrow contract address, zero address if not found
     *
     * @param _escrow The escrow contract address
     * @return string The order id
     */
    function getOrderIdByEscrow(address _escrow) external view returns (string memory) {
        return escrowToOrderId[_escrow];
    }

    /**
     * @dev Sets the implementation contract address after deployment
     *
     * @param _newImplementation The new implementation contract address
     */
    function setImplementation(address _newImplementation) external onlyOwner {
        _setImplementation(_newImplementation);
    }

    /**
     * @dev Internal logic to set the implementation contract address
     */
    function _setImplementation(address _newImplementation) internal {
        //////////////
        /// CHECKS ///
        //////////////

        // Ensure the new implementation address is not 0x0
        if (_newImplementation == address(0)) {
            revert ZeroAddress();
        }

        // Ensure the new implementation address is not the same as the current implementation address
        if (_newImplementation == address(implementation)) {
            revert NoChange();
        }

        // Check if the __init__() function exists in the implementation contract
        if (!_hasInitFunction(_newImplementation)) {
            revert ImplementationHasInvalidInit();
        }

        ///////////////
        /// EFFECTS ///
        ///////////////

        // Set the new implementation contract address
        implementation = IGigabitEscrowOrder(_newImplementation);

        emit SetImplementation(_newImplementation);

        ////////////////////
        /// INTERACTIONS ///
        ////////////////////

        // For the new implementation contract, have it set itself as the implementation
        IGigabitEscrowOrder(_newImplementation).setAsImplementation();
    }

    /**
     * @dev Sets the number of days for a customer to not respond to submitted work before a worker can claim funds
     *
     * @param _customerTimeoutDays The new number of days for a customer to not respond to submitted work before a worker can claim funds
     */
    function setCustomerTimeoutDays(uint8 _customerTimeoutDays) external onlyOwner {

        //////////////
        /// CHECKS ///
        //////////////

        // Ensure the new customer timeout days is greater than 0
        if (_customerTimeoutDays == 0) {
            revert ZeroValue();
        }

        // Ensure the new customer timeout days is not the same as the current customer timeout days
        if (_customerTimeoutDays == customerTimeoutDays) {
            revert NoChange();
        }

        ///////////////
        /// EFFECTS ///
        ///////////////

        customerTimeoutDays = _customerTimeoutDays;
    }

    /**
     * @dev Sets the maximum number of days a customer has to start a job
     *
     * @param _maxStartByDays The new max number of days a customer has to start a job
     */
    function setMaxStartByDays(uint8 _maxStartByDays) external onlyOwner {

        //////////////
        /// CHECKS ///
        //////////////

        // Ensure the new max start by days is greater than 0
        if (_maxStartByDays == 0) {
            revert ZeroValue();
        }

        // Ensure the new max start by days is not the same as the current max start by days
        if (_maxStartByDays == maxStartByDays) {
            revert NoChange();
        }

        ///////////////
        /// EFFECTS ///
        ///////////////

        maxStartByDays = _maxStartByDays;

        emit SetMaxStartByDays(maxStartByDays);
    }

    /**
     * @dev Sets the maximum number of days a customer has to pay for a job
     *
     * @param _maxPayByDays The new max number of days a customer has to pay for a job
     */
    function setMaxPayByDays(uint8 _maxPayByDays) external onlyOwner {

        //////////////
        /// CHECKS ///
        //////////////

        // Ensure the new max pay by days is greater than 0
        if (_maxPayByDays == 0) {
            revert ZeroValue();
        }

        // Ensure the new max pay by days is not the same as the current max pay by days
        if (_maxPayByDays == maxPayByDays) {
            revert NoChange();
        }

        ///////////////
        /// EFFECTS ///
        ///////////////

        maxPayByDays = _maxPayByDays;

        emit SetMaxPayByDays(maxPayByDays);
    }

    /**
     * @dev Sets the maximum percentage of the total job cost the company can take as a fee
     *
     * @param _maxCompanyPercentageCut The new max percentage of the total job cost the company can take as a fee
     */
    function setMaxCompanyPercentageCut(uint8 _maxCompanyPercentageCut) external onlyOwner {

        //////////////
        /// CHECKS ///
        //////////////

        // Ensure the new max company percentage cut is greater than 0
        if (_maxCompanyPercentageCut == 0) {
            revert ZeroValue();
        }

        // Ensure the new max company percentage cut is not the same as the current max company percentage cut
        if (_maxCompanyPercentageCut == maxCompanyPercentageCut) {
            revert NoChange();
        }

        // Ensure the new max company percentage cut is not too high
        if (_maxCompanyPercentageCut > COMPANY_PERCENTAGE_CUT_CEILING) {
            revert CompanyPercentageCutExceedsMax();
        }

        ///////////////
        /// EFFECTS ///
        ///////////////

        maxCompanyPercentageCut = _maxCompanyPercentageCut;

        emit SetMaxCompanyPercentageCut(maxCompanyPercentageCut);
    }

    /**
     * @dev Sets the maximum number of work days a worker can request for newly-created escrow contracts
     *
     * @param _maxDaysToComplete The new max number of work days a worker can request
     */
    function setMaxDaysToComplete(uint8 _maxDaysToComplete) external onlyOwner {

        //////////////
        /// CHECKS ///
        //////////////

        // Ensure the new max days to complete is greater than 0
        if (_maxDaysToComplete == 0) {
            revert ZeroValue();
        }

        // Ensure the new max days to complete is not the same as the current max days to complete
        if (_maxDaysToComplete == maxDaysToComplete) {
            revert NoChange();
        }
        
        // Ensure the new max days to complete is not too high
        if (_maxDaysToComplete > MAX_DAYS_TO_COMPLETE_CEILING) {
            revert MaxDaysToCompleteExceedsMax();
        }

        ///////////////
        /// EFFECTS ///
        ///////////////

        maxDaysToComplete = _maxDaysToComplete;

        emit SetMaxDaysToComplete(maxDaysToComplete);
    }

    /**
     * @dev Sets the maximum number of revisions a customer can request for newly-created escrow contracts
     *
     * @param _maxRevisions The new maximum number of revisions a customer can request
     */
    function setMaxRevisions(uint8 _maxRevisions) external onlyOwner {

        //////////////
        /// CHECKS ///
        //////////////

        // Ensure the new max revisions is greater than 0
        if (_maxRevisions == 0) {
            revert ZeroValue();
        }
        
        // Ensure the new max revisions is not the same as the current max revisions
        if (_maxRevisions == maxRevisions) {
            revert NoChange();
        }
        
        // Ensure the new max revisions is not too high
        if (_maxRevisions > MAX_REVISIONS_CEILING) {
            revert MaxRevisionsExceedsMax();
        }

        ///////////////
        /// EFFECTS ///
        ///////////////

        maxRevisions = _maxRevisions;

        emit SetMaxRevisions(maxRevisions);
    }

    /**
     * @dev Sets the maximum number of extensions a customer can request for newly-created escrow contracts
     *
     * @param _maxExtensions The new maximum number of extensions a customer can request
     */
    function setMaxExtensions(uint8 _maxExtensions) external onlyOwner {

        //////////////
        /// CHECKS ///
        //////////////

        // Ensure the new max extensions is greater than 0
        if (_maxExtensions == 0) {
            revert ZeroValue();
        }

        // Ensure the new max extensions is not the same as the current max extensions
        if (_maxExtensions == maxExtensions) {
            revert NoChange();
        }
        
        // Ensure the new max extensions is not too high
        if (_maxExtensions > MAX_EXTENSIONS_CEILING) {
            revert MaxExtensionsExceedsMax();
        }

        ///////////////
        /// EFFECTS ///
        ///////////////
        
        maxExtensions = _maxExtensions;

        emit SetMaxRevisions(maxRevisions);
    }

    /**
     * @dev Checks if an address is an externally owned account (EOA) or a smart contract
     *
     * @param _addressToCheck The address to be checked
     * @return bool TRUE if the address is an EOA, FALSE otherwise
     **/
    function _isEOA(address _addressToCheck) internal view returns (bool) {

        // Zero address checks should be performed upstream

        uint256 _codeSize;
        assembly {
            _codeSize := extcodesize(_addressToCheck)
        }
        return _codeSize == 0;
    }

    /**
     * @dev Reports an address for a given order id, called by the escrow contract
     *
     * @param _reporter The address of the reporter
     * @param _reported The address of the reported
     * @param _orderId The order id
     */
    function reportInOrder(address _reporter, address _reported, string memory _orderId) external onlyAuthorizedClone {

        // Set up in-memory reads from storage
        address _escrow = _msgSender();
        address _customer = IGigabitEscrowOrder(_escrow).customer();
        address _worker = IGigabitEscrowOrder(_escrow).worker();

        //////////////
        /// CHECKS ///
        //////////////

        if (_reporter == address(0) 
            || _reported == address(0)
        ) {
            revert ZeroAddress();
        }

        if (_reporter == _reported) {
            revert CannotReportYourself();
        }

        // Ensure the reporter is either the customer or the worker
        if (_reporter != _customer 
            && _reporter != _worker
        ) {
            revert Unauthorized();
        }

        // Ensure the reported is either the customer or the worker
        if (_reported != _customer 
            && _reported != _worker
        ) {
            revert Unauthorized();
        }

        ///////////////
        /// EFFECTS ///
        ///////////////

        emit ReportedInOrder(_reporter, _reported, _orderId);

        ////////////////////
        /// INTERACTIONS ///
        ////////////////////

        if (statisticsPause == false) {
            statistics.report(_reporter, _reported);
        }
    }

    /**
     * @dev Checks if a given address has the matching __init__() function in its contract code
     *
     * @param _newImplementation The address to check
     * @return bool TRUE if the address has the __init__() function, FALSE otherwise
     */
    function _hasInitFunction(address _newImplementation) private view returns (bool) {
        // The function selector for the __init__() function
        bytes4 _functionSelector = bytes4(
            keccak256(
                bytes(
                    "__init__((address[],uint256[],uint64[],uint8[],string[],bool[]))"
                )
            )
        );

        // Fetch size of contract code
        uint256 _codeSize;
        assembly {
            _codeSize := extcodesize(_newImplementation)
        }

        // If there's no code, return false
        if (_codeSize == 0) return false;

        // Fetch the contract code
        bytes memory _codeData = new bytes(_codeSize);
        assembly {
            extcodecopy(_newImplementation, add(_codeData, 0x20), 0, _codeSize)
        }

        // Check if the function selector exists within the contract code
        for (uint256 i = 0; i < _codeData.length - 4; i++) {
            if (
                _codeData[i] == _functionSelector[0] &&
                _codeData[i + 1] == _functionSelector[1] &&
                _codeData[i + 2] == _functionSelector[2] &&
                _codeData[i + 3] == _functionSelector[3]
            ) {
                return true;
            }
        }
        return false;
    }

    /**
     * @dev Allows an authorized address that can generate escrow contracts switch keys to a new address.
     *      This is good practice to rotate keys on a regular basis. Also useful in the event of a security 
     *      incident or if employees with access to sensitive information leave the company.
     *
     * @param _newAddress The address to set
     */
    function rotate(address _newAddress) external {

        // Set up in-memory reads from storage
        address _oldAddress = _msgSender();
        bool _rotationPause = rotationPause;

        //////////////
        /// CHECKS ///
        //////////////

        // Ensure the new address is not 0x0
        if (_newAddress == address(0)) {
            revert ZeroAddress();
        }

        // Ensure the old address is authorized to generate escrow contracts
        if (authorizedMap[_oldAddress] == 0) {
            revert Unauthorized();
        }

        // Ensure the new address is not the same as the old address
        if (_newAddress == _oldAddress) {
            revert NoChange();
        }

        // Ensure that more than 1 day has passed since the last key rotation
        // This is to prevent a compromised account from rotating the key too frequently
        if (block.timestamp - authorizedMap[_oldAddress] < (minRotationIntervalDays * 1 days)) {
            revert RotationTooSoon();
        }

        // Ensure the key rotation is not paused
        // This is to prevent a compromised account from rotating the key to a new address
        // The owner can pause the key rotation in the event of a security incident
        if (_rotationPause == true) {
            revert RotationPaused();
        }

        ///////////////
        /// EFFECTS ///
        ///////////////

        authorizedMap[_oldAddress] = 0;
        authorizedMap[_newAddress] = block.timestamp;

        emit Rotation(_oldAddress, _newAddress);
    }

    /**
     * @dev Allows the contract owner to add an address that can generate escrow contracts
     *
     * @param _address The address to add
     */
    function addAuthorized(address _address) external onlyOwner {

        //////////////
        /// CHECKS ///
        //////////////

        if (_address == address(0)) {
            revert ZeroAddress();
        }

        if (authorizedMap[_address] != 0) {
            revert NoChange();
        }

        if (_address == owner()) {
            revert CannotBeOwner();
        }

        ///////////////
        /// EFFECTS ///
        ///////////////

        authorizedMap[_address] = block.timestamp;

        emit AddedAuthorized(_address);
    }

    /**
     * @dev Allows the contract owner to remove an address that can generate escrow contracts
     *
     * @param _address The address to remove
     */
    function removeAuthorized(address _address) external onlyOwner {

        //////////////
        /// CHECKS ///
        //////////////

        if (_address == address(0)) {
            revert ZeroAddress();
        }

        if (authorizedMap[_address] == 0) {
            revert NoChange();
        }

        ///////////////
        /// EFFECTS ///
        ///////////////

        authorizedMap[_address] = 0;

        emit RemovedAuthorized(_address);
    }

    /**
     * @dev Pauses or unpauses the key rotation functionality
     *
     * @param _value The value to set
     */
    function setRotationPause(bool _value) external onlyOwner {

        // Set up in-memory reads from storage
        bool _rotationPause = rotationPause;

        //////////////
        /// CHECKS ///
        //////////////

        if (_rotationPause == _value) {
            revert NoChange();
        }

        ///////////////
        /// EFFECTS ///
        ///////////////

        rotationPause = _value;

        emit RotationPause(_value);
    }

    /**
     * @dev Pauses or unpauses the statistics functionality
     *
     * @param _value The value to set
     */
    function setStatisticsPause(bool _value) external onlyOwner {

        // Set up in-memory reads from storage
        bool _statisticsPause = statisticsPause;

        //////////////
        /// CHECKS ///
        //////////////

        if (_statisticsPause == _value) {
            revert NoChange();
        }

        ///////////////
        /// EFFECTS ///
        ///////////////

        statisticsPause = _value;

        emit StatisticsPause(_value);
    }

    /**
     * @dev Stops the creation of new escrow contracts, in case we want 
     *      to upgrade this contract or if there is a security incident
     */
    function setEscrowCreationPause(bool _value) external onlyOwner {

        // Set up in-memory reads from storage
        bool _escrowCreationPause = escrowCreationPause;

        //////////////
        /// CHECKS ///
        //////////////

        if (_escrowCreationPause == _value) {
            revert NoChange();
        }

        ///////////////
        /// EFFECTS ///
        ///////////////

        escrowCreationPause = _value;

        emit EscrowCreationPause(_value);
    }

    /**
     * @dev Initializes the valid transitions for the work status
     **/
    function _initializeTransitions() internal {
        validTransitions[SharedTypes.WorkStatus.IN_QUEUE][SharedTypes.WorkStatus.IN_PROGRESS] = true;
        validTransitions[SharedTypes.WorkStatus.IN_QUEUE][SharedTypes.WorkStatus.CANCELED] = true;
        validTransitions[SharedTypes.WorkStatus.IN_QUEUE][SharedTypes.WorkStatus.IN_DISPUTE] = true;
        validTransitions[SharedTypes.WorkStatus.IN_PROGRESS][SharedTypes.WorkStatus.IN_REVIEW] = true;
        validTransitions[SharedTypes.WorkStatus.IN_PROGRESS][SharedTypes.WorkStatus.CANCELED] = true;
        validTransitions[SharedTypes.WorkStatus.IN_PROGRESS][SharedTypes.WorkStatus.IN_DISPUTE] = true;
        validTransitions[SharedTypes.WorkStatus.IN_REVIEW][SharedTypes.WorkStatus.IN_PROGRESS] = true;
        validTransitions[SharedTypes.WorkStatus.IN_REVIEW][SharedTypes.WorkStatus.CANCELED] = true;
        validTransitions[SharedTypes.WorkStatus.IN_REVIEW][SharedTypes.WorkStatus.IN_DISPUTE] = true;
        validTransitions[SharedTypes.WorkStatus.IN_REVIEW][SharedTypes.WorkStatus.COMPLETED] = true;
        validTransitions[SharedTypes.WorkStatus.IN_DISPUTE][SharedTypes.WorkStatus.CANCELED] = true;
        validTransitions[SharedTypes.WorkStatus.IN_DISPUTE][SharedTypes.WorkStatus.SETTLED] = true;
        validTransitions[SharedTypes.WorkStatus.IN_DISPUTE][SharedTypes.WorkStatus.COMPLETED] = true;
        validTransitions[SharedTypes.WorkStatus.IN_QUEUE][SharedTypes.WorkStatus.TERMINATED] = true;
        validTransitions[SharedTypes.WorkStatus.IN_PROGRESS][SharedTypes.WorkStatus.TERMINATED] = true;
        validTransitions[SharedTypes.WorkStatus.IN_REVIEW][SharedTypes.WorkStatus.TERMINATED] = true;
        validTransitions[SharedTypes.WorkStatus.IN_DISPUTE][SharedTypes.WorkStatus.TERMINATED] = true;
    }

    /**
     * @dev Checks if a transition between two work statuses is valid
     */
    function isValidTransition(
        SharedTypes.WorkStatus _oldStatus,
        SharedTypes.WorkStatus _newStatus
    ) external view returns (bool) {
        return validTransitions[_oldStatus][_newStatus];
    }

    function setPaymaster(address _paymaster) external onlyOwner {
        paymaster = IGigabitEscrowPaymaster(_paymaster);
    }

    function setForwarder(address _forwarder) external onlyOwner {
        _setTrustedForwarder(_forwarder);
    }

    function fundEscrow(
        string memory _orderID,
        address _stableToken,
        uint256 _amountUSDPennies,
        uint256 _deadline,
        uint8 _v,
        bytes32 _r,
        bytes32 _s
    ) external {

        // validate that the stable token is registered
        if (isRegisteredStableToken(_stableToken) == false) {
            revert StableTokenNotRegistered();
        }

        // NOTE: we do NOT validate if an escrow contract already exists for this order id,
        // as the current flow requires that we fund the predicted escrow contract address
        // with the amount due + service fee before the escrow contract is created

        address _predictedEscrow = getPredictedEscrowByOrderId(_orderID);

        // Scope: Calculate the amount of stable token to fund the escrow contract
        uint256 _stableTokenAmount;
        {
            uint8 _stableTokenDecimals = registeredStableTokenMap[_stableToken];

            // calculate the amount of stable token to fund the escrow contract from the pennies amount
            uint8 _adjustedDecimals = _stableTokenDecimals - 2; // shift 2 decimals for pennies
             _stableTokenAmount = _amountUSDPennies * (10 ** _adjustedDecimals);
        }

        // transfer the stable token to the predicted escrow contract address
        transferWithPermit(
            _stableToken,
            _msgSender(),
            _predictedEscrow,
            _stableTokenAmount,
            _deadline,
            _v,
            _r,
            _s
        );
    }

    function transferWithPermit(
        address _token,
        address _from,
        address _to,
        uint256 _amount,
        uint256 _deadline,
        uint8 _v,
        bytes32 _r,
        bytes32 _s
    ) internal {
        // Step 1: Execute the permit to approve this contract for spending
        IERC20Permit(_token).permit(_from, address(this), _amount, _deadline, _v, _r, _s);

        // Step 2: Transfer the tokens
        IERC20(_token).transferFrom(_from, _to, _amount);
    }
}
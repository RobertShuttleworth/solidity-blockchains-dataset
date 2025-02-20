// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import "./contracts_HandlesGSN.sol";
import "./lib_OpenZeppelin_token_ERC20_IERC20.sol";
import "./lib_OpenZeppelin_token_ERC20_utils_SafeERC20.sol";
import "./lib_OpenZeppelin_utils_ReentrancyGuard.sol";
import "./contracts_IGigabitEscrowManager.sol";
import "./contracts_SharedTypes.sol";

/**
 * @title GigabitEscrowOrder
 *
 * @notice This contract is the implementation contract for Gigabit Escrow orders. It is intended
 *         to be cloned by the EscrowManager contract. For this reason, there is no constructor,
 *         but instead an __init__ function that is called by the EscrowManager contract upon
 *         cloning. This allows us to cheaply clone the contract and initialize it with all the
 *         appropriate parameters. If we need to relaunch this contract to with modified parameters,
 *         we have the flexibility to do so without needing to relaunch the EscrowManager contract.
 *
 * @author David Wyly, a.k.a. Carc
 *         david{at}decentrasoftware.com
 *
 * @dev Throughout this contract, we adopt a memory preloading strategy by loading storage variables
 * into in-memory variables at the onset of functions. The initial SLOAD operation costs 800 gas,
 * whereas subsequent memory operations, MSTORE and MLOAD, are just 3 gas each.
 *
 * This approach:
 * 1. Prevents inadvertent multiple SLOAD operations for a single variable.
 * 2. Ensures consistent behavior by keeping the in-memory values stable throughout the function.
 * 3. Reduces reentrancy attack vectors since state variables, once read, aren't directly modified
 *    during function execution.
 * 4. Facilitates more complex operations and calculations without direct storage mutations.
 * 5. Simplifies debugging by providing clear visibility into initial data values.
 * 6. Is extremely unlikely to trigger quadratic gas costs as we're not looping over storage arrays.
 */
contract GigabitEscrowOrder is HandlesGSN, ReentrancyGuard {
    using SafeERC20 for IERC20;

    // Addresses
    address public manager;     // The EscrowManager contract
    address public stableToken; // The token used for payment 
    address public worker;      // The worker's address (fulfills the order)
    address public customer;    // The customer's address (pays for the order)
    address public affiliate;   // The affiliate's address (takes a cut of the worker's payout)
    address public referrer;    // The referrer's address (takes a cut of the company's payout)

    // Unsigned 256 bit integers
    uint256 public amountDue;  // The amount due for the order (in stableToken, including decimals)
    uint256 public serviceFee; // The fee charged by the company for the service (in stableToken, including decimals)

    // Unsigned 64 bit integers
    uint64 public queuedAt;                     // The timestamp when the order was queued
    uint64 public startBy;                      // The timestamp by which the worker must start the order
    uint64 public startedAt;                    // The timestamp when the worker started the order
    uint64 public closedAt;                     // The timestamp when the order was closed
    uint64 public emergencyWithdrawProposalAt;  // The timestamp when the emergency withdraw was proposed

    // Unsigned 8 bit integers
    uint8 public daysToComplete;         // The number of days the worker has to complete the order
    uint8 public revisionRequestsLeft;   // The number of revisions the customer can request
    uint8 public extensionRequestsLeft;  // The number of extensions the worker can request
    uint8 public extensionRequestDays;   // The number of days the worker has requested to extend
    uint8 public companyPercentageCut;   // The percentage cut the company takes from worker's payout
    uint8 public affiliatePercentageCut; // The percentage cut the affiliate takes from worker's payout (after company cut)
    uint8 public referrerPercentageCut;  // The percentage cut the referrer takes from company's payout

    // Strings
    string public orderId;

    // Boolean flags
    bool public initialized;      // TRUE if the contract has been initialized
    bool public isImplementation; // TRUE if this contract is the implementation contract
    bool public workerReported;   // TRUE if the worker has been reported
    bool public customerReported; // TRUE if the customer has been reported
    bool public devMode;          // TRUE if the contract is in developer mode

    // Constants
    uint8 public constant MAX_COMPANY_PERCENTAGE_CUT_CEILING = 35;   // The maximum percentage cut the company can take
    uint8 public constant MAX_AFFILIATE_PERCENTAGE_CUT_CEILING = 35; // The maximum percentage cut the affiliate can take
    uint8 public constant MAX_REFERRER_PERCENTAGE_CUT_CEILING = 35;  // The maximum percentage cut the referrer can take

    struct Split {
        uint256 amountToCompany;
        uint256 amountToWorker;
        uint256 amountToCustomer;
        uint256 amountToAffiliate;
        uint256 amountToReferrer;
    }

    // Arrays
    SharedTypes.WorkStatusUpdate[] public workStatusUpdates;
    SharedTypes.DisputeRulingUpdate[] public disputeRulingUpdates;

    SharedTypes.WorkStatus public workStatus;
    SharedTypes.DisputeRuling public disputeRuling;

    // Modifiers
    modifier onlyCustomer() {
        if (_msgSender() != customer) {
            revert Unauthorized();
        }
        _;
    }
    modifier onlyWorker() {
        if (_msgSender() != worker) {
            revert Unauthorized();
        }
        _;
    }
    modifier onlyCompany() {
        if (_msgSender() != IGigabitEscrowManager(manager).owner()) {
            revert Unauthorized();
        }
        _;
    }
    modifier isPaid() {
        if (fullPaymentInContract() == false) {
            revert OrderNotPaid();
        }
        _;
    }

    // Events
    event RevisionRequested(string indexed orderId);
    event RevisionGifted(string indexed orderId, uint8 extraRevisions);
    event ExtensionRequested(string indexed orderId, uint8 extraDays);
    event ExtensionRequestAccepted(string indexed orderId, uint8 extraDays);
    event ExtensionRequestRejected(string indexed orderId);
    event OrderInDispute(string indexed orderId);
    event DisputeResolvedFavoringCustomer(string indexed orderId);
    event DisputeResolvedFavoringWorker(string indexed orderId);
    event DisputeResolvedAsCompromise(
        string indexed orderId,
        uint256 refundedAmount,
        uint256 payoutAmount
    );
    event RecoveredOrphanedEther(uint256 amount);
    event RecoveredOrphanedTokens(address indexed token, uint256 amount);
    event EmergencyWithdrawProposed(
        string indexed orderId,
        uint256 contractAmount
    );
    event EmergencyWithdrawProposalCanceled(string indexed orderId);
    event EmergencyWithdraw(string indexed orderId, uint256 contractAmount);
    event WorkStatusUpdated(string indexed orderId, SharedTypes.WorkStatus workStatus);
    event DisputeRulingUpdated(
        string indexed orderId,
        SharedTypes.DisputeRuling disputeRuling
    );
    event ImplementationSet();

    // Errors
    error Unauthorized();
    error InvalidInput();
    error AlreadyInitialized();
    error ImplementationAlreadySet();
    error ImplementationRestricted();
    error ZeroAddress();
    error ZeroValue();
    error EmptyString();
    error AddressesNotUnique();
    error MustBeEOA();
    error CannotBeEOA();
    error PastValue();
    error ExceedsMax();
    error OrderPaid();
    error OrderNotPaid();
    error OrderNotTimedOut();
    error PaymentNotLate();
    error InvalidWorkStatus();
    error InvalidDisputeRuling();
    error InvalidServiceFee();
    error ExtensionRequestAlreadyPending();
    error ExtensionRequestNotPending();
    error ExtensionRequestsDepleted();
    error RevisionRequestAlreadyPending();
    error RevisionRequestNotPending();
    error RevisionRequestsDepleted();
    error RevisionRequestsAvailable();
    error MissingWorkStatusUpdate();
    error EmptyBalance();
    error InsufficientBalance();
    error TransferFailed();
    error RestrictedToken();
    error EmergencyWithdrawAlreadyProposed();
    error EmergencyWithdrawNotProposed();
    error TimelockNotExpired();
    error CompanyCutUnderflow();
    error WorkerCutUnderflow();
    error WorkerFinalCutUnderflow();
    error CustomerCutUnderflow();
    error DevModeDisabled();

    /**
     * @dev Initializes the order
     *
     * @notice Initializes the contract post-cloning by the EscrowManager. Not for direct external use.
     *         This initialization method is designed with upgradeability in mind, allowing for future 
     *         implementation swaps without disrupting the EscrowManager's operation. It maintains a 
     *         consistent function signature to ensure compatibility across versions. To adapt to new 
     *         requirements, extend the function to accept additional parameters, keeping the signature 
     *         unchanged, then redeploy and register the new implementation with the EscrowManager.
     *
     * @param _params EscrowParams struct containing the necessary parameters to initialize the contract
     */
    function __init__(SharedTypes.EscrowParams calldata _params) external {

        // Input arrays are strictly bound
        if (_params.addresses.length != 5 ||
            _params.uint256s.length != 2 ||
            _params.uint64s.length != 1 ||
            _params.uint8s.length != 6 ||
            _params.strings.length != 1 ||
            _params.bools.length != 1) 
        {
            revert InvalidInput();
        }

        // Contract can only be initialized once
        if (initialized == true) {
            revert AlreadyInitialized();
        }

        // Implementation contract cannot be initialized
        if (isImplementation == true) {
            revert ImplementationRestricted();
        }

        // Because this contract is cloned and initialized by the EscrowManager contract all
        // in a single transaction, we can be sure that the msg.sender is the EscrowManager
        address _manager = _msgSender();

        // Scope 1: Handle addresses
        address _affiliate;
        address _referrer;
        {
            // Unpack addresses
            address _stableToken = _params.addresses[0];
            address _customer = _params.addresses[1];
            address _worker = _params.addresses[2];
            _affiliate = _params.addresses[3];
            _referrer = _params.addresses[4];

            // Check for zero addresses
            if (_stableToken == address(0) 
                || _customer == address(0)
                || _worker == address(0)
                // Affiliate can be address(0)
                // Referrer can be address(0)
            ) {
                revert ZeroAddress();
            }

            // Check for unique addresses
            if (_stableToken == _customer
                || _stableToken == _worker
                || _customer == _worker
                || _customer == _affiliate
                || _customer == _referrer
                || _worker == _affiliate
                || _worker == _referrer
                // Affiliate can be the same as referrer
            ) {
                revert AddressesNotUnique();
            }

            // Check if EOA or contract
            if (!_isEOA(_customer) 
                || !_isEOA(_worker)
                || !_isEOA(_affiliate)
                || !_isEOA(_referrer)
            ) {
                revert MustBeEOA();
            }
            if (_isEOA(_stableToken)) {
                revert CannotBeEOA();
            }

            // Initialize addresses
            stableToken = _stableToken;
            customer = _customer;
            worker = _worker;
            affiliate = _affiliate;
            referrer = _referrer;
        }

        // Scope 2: Handle uint256s
        {
            // Unpack uint256s
            uint256 _amountDue = _params.uint256s[0];
            uint256 _serviceFee = _params.uint256s[1];

            // Check for zero values
            // note: serviceFee can be 0
            if (_amountDue == 0) {
                revert ZeroValue();
            }

            // Initialize uint256s
            amountDue = _amountDue;
            serviceFee = _serviceFee;
        }

        // Scope 3: Handle uint64s
        {
            // Unpack uint64s
            uint64 _startBy = _params.uint64s[0];

            if (_startBy == 0) {
                revert ZeroValue();
            }
            if (_startBy < block.timestamp) {
                revert PastValue();
            }

            // Initialize uint64s
            startBy = _startBy;
        }

        // Scope 4: Handle string
        {
            // Unpack strings
            string memory _orderId = _params.strings[0];

            // Check for empty string
            if (bytes(_orderId).length == 0) {
                revert EmptyString();
            }

            // Initialize strings
            orderId = _orderId;
        }

        // Scope 5: Handle uint8s
        uint8 _affiliatePercentageCut;
        uint8 _referrerPercentageCut;
        {
            // Unpack uint8s
            uint8 _companyPercentageCut = _params.uint8s[0];
            uint8 _daysToComplete = _params.uint8s[1];
            uint8 _revisionRequestsLeft = _params.uint8s[2];
            uint8 _extensionRequestsLeft = _params.uint8s[3];
            _affiliatePercentageCut = _params.uint8s[4];
            _referrerPercentageCut = _params.uint8s[5];

            // Check for max values
            if (_companyPercentageCut > MAX_COMPANY_PERCENTAGE_CUT_CEILING
                || _companyPercentageCut > IGigabitEscrowManager(_manager).maxCompanyPercentageCut()
                || _daysToComplete > IGigabitEscrowManager(_manager).maxDaysToComplete()
                || _revisionRequestsLeft > IGigabitEscrowManager(_manager).maxRevisions()
                || _extensionRequestsLeft > IGigabitEscrowManager(_manager).maxExtensions()
                || _affiliatePercentageCut > MAX_AFFILIATE_PERCENTAGE_CUT_CEILING
                || _referrerPercentageCut > MAX_REFERRER_PERCENTAGE_CUT_CEILING
            ) {
                revert ExceedsMax();
            }

            if (_companyPercentageCut == 0
                || _daysToComplete == 0
                || _revisionRequestsLeft == 0
                || _extensionRequestsLeft == 0
            ) {
                revert ZeroValue();
            }

            // Initialize unint8s
            companyPercentageCut = _companyPercentageCut;
            daysToComplete = _daysToComplete;
            revisionRequestsLeft = _revisionRequestsLeft;
            extensionRequestsLeft = _extensionRequestsLeft;
            affiliatePercentageCut = _affiliatePercentageCut;
            referrerPercentageCut = _referrerPercentageCut;
        }

        // Scope 6: Handle bools
        {
            // Unpack bools
            bool _devMode = _params.bools[0];

            // initialize bools
            devMode = _devMode;
        }

        // Scope 6: Additional validation for mixed SharedTypes
        {
            if (_affiliatePercentageCut == 0 && _affiliate != address(0)) {
                revert ZeroValue();
            }
            if (_referrerPercentageCut == 0 && _referrer != address(0)) {
                revert ZeroValue();
            }
            if (_affiliate == address(0) && _affiliatePercentageCut > 0) {
                revert ZeroAddress();
            }
            if (_referrer == address(0) && _referrerPercentageCut > 0) {
                revert ZeroAddress();
            }
        }

        // Scope 7: Set remaining variables
        {
            manager = _manager;
            queuedAt = uint64(block.timestamp);
            workStatus = SharedTypes.WorkStatus.IN_QUEUE;
            initialized = true;
        }
    }

    /**
     * @dev Returns the amount required to fully pay the order
     */
    function getBalanceDeficit() external view returns (uint256) {
        // Set up in-memory reads from storage
        address _stableToken = stableToken;
        uint256 _amountDue = amountDue;
        uint256 _serviceFee = serviceFee;
        uint256 _balance = IERC20(_stableToken).balanceOf(address(this));

        // Calculate the total amount due
        uint256 _totalAmountDue = _amountDue + _serviceFee;

        if (_totalAmountDue > _balance) {
            return _totalAmountDue - _balance;
        } else {
            return 0;
        }
    }

    /////////////////////////////
    /// WORKER-ONLY FUNCTIONS ///
    /////////////////////////////

    function signalRequirementsSet() external onlyCustomer {
        // Set up in-memory reads from storage
        SharedTypes.WorkStatus _currentWorkStatus = workStatus;

        //////////////
        /// CHECKS ///
        //////////////

        // Work status must be IN_QUEUE
        if (_currentWorkStatus != SharedTypes.WorkStatus.IN_QUEUE) {
            revert InvalidWorkStatus();
        }

        ///////////////
        /// EFFECTS ///
        ///////////////

        _setWorkStatus(_currentWorkStatus, SharedTypes.WorkStatus.IN_QUEUE);
    }

    /**
     * @dev Worker flags that they have started work
     **/
    function signalInProgress() external onlyWorker isPaid {
        // Set up in-memory reads from storage
        SharedTypes.WorkStatus _currentWorkStatus = workStatus;

        //////////////
        /// CHECKS ///
        //////////////

        // Work status must be IN_QUEUE
        if (_currentWorkStatus != SharedTypes.WorkStatus.IN_QUEUE) {
            revert InvalidWorkStatus();
        }

        ///////////////
        /// EFFECTS ///
        ///////////////

        _setWorkStatus(_currentWorkStatus, SharedTypes.WorkStatus.IN_PROGRESS);
    }

    /**
     * @dev Worker has something for the customer to evaluate
     **/
    function signalInReview() external onlyWorker isPaid {
        // Set up in-memory reads from storage
        SharedTypes.WorkStatus _currentWorkStatus = workStatus;

        //////////////
        /// CHECKS ///
        //////////////

        // Work status must be either IN_PROGRESS
        if (_currentWorkStatus != SharedTypes.WorkStatus.IN_PROGRESS
        ) {
            revert InvalidWorkStatus();
        }

        ///////////////
        /// EFFECTS ///
        ///////////////

        _setWorkStatus(_currentWorkStatus, SharedTypes.WorkStatus.IN_REVIEW);
    }

    /**
     * @dev Worker can ask for more time to complete the work
     **/
    function requestExtension(uint8 _extensionRequestDays) external onlyWorker isPaid {
        // Set up in-memory reads from storage
        address _manager = manager;
        string memory _orderId = orderId;
        uint8 _daysToComplete = daysToComplete;
        uint8 _extensionRequestsLeft = extensionRequestsLeft;
        SharedTypes.WorkStatus _currentWorkStatus = workStatus;

        //////////////
        /// CHECKS ///
        //////////////

        // Work status must be IN_PROGRESS or IN_REVIEW
        if (_currentWorkStatus != SharedTypes.WorkStatus.IN_PROGRESS
            && _currentWorkStatus != SharedTypes.WorkStatus.IN_REVIEW
        ) {
            revert InvalidWorkStatus();
        }

        // Extension requests left must be greater than 0
        if (_extensionRequestsLeft == 0) {
            revert ExtensionRequestsDepleted();
        }
        
        if (_extensionRequestDays == 0) {
            revert ZeroValue();
        }

        // Calculate the number of max work days after the request
        _daysToComplete += _extensionRequestDays;
        if (_daysToComplete > IGigabitEscrowManager(_manager).maxDaysToComplete()) {
            revert ExceedsMax();
        }

        ///////////////
        /// EFFECTS ///
        ///////////////

        // Decrement the number of extension requests left
        extensionRequestsLeft--;

        // Set the number of extension days
        extensionRequestDays = _extensionRequestDays;

        // Emit the event
        emit ExtensionRequested(_orderId, _extensionRequestDays);
    }

    /**
     * @dev Worker may gift revisions to the customer
     **/
    function giftRevision(uint8 _revisionGiftCount) external onlyWorker isPaid {
        // Set up in-memory reads from storage
        address _manager = manager;
        string memory _orderId = orderId;
        uint8 _revisionRequestsLeft = revisionRequestsLeft;
        SharedTypes.WorkStatus _currentWorkStatus = workStatus;

        //////////////
        /// CHECKS ///
        //////////////

        // Work status must be IN_QUEUE, IN_PROGRESS, or IN_REVIEW
        if (_currentWorkStatus != SharedTypes.WorkStatus.IN_QUEUE
            && _currentWorkStatus != SharedTypes.WorkStatus.IN_PROGRESS
            && _currentWorkStatus != SharedTypes.WorkStatus.IN_REVIEW
        ) {
            revert InvalidWorkStatus();
        }

        if (_revisionGiftCount == 0) {
            revert ZeroValue();
        }

        ///////////////
        /// EFFECTS ///
        ///////////////

        // Calculate the number of revision requests left after the gift
        uint8 _newRevisionRequestsLeft = _revisionRequestsLeft +
            _revisionGiftCount;
        if (
            _newRevisionRequestsLeft >
            IGigabitEscrowManager(_manager).maxRevisions()
        ) {
            revert ExceedsMax();
        }

        // Add the revision gift count to the number of revision requests left
        revisionRequestsLeft = _newRevisionRequestsLeft;

        // Emit the event
        emit RevisionGifted(_orderId, _revisionGiftCount);
    }

    /**
     * @dev Worker can cancel for any reason, but they will be penalized and customer will be refunded
     **/
    function cancelDueToWorkerQuitting() external onlyWorker nonReentrant isPaid {
        // Set up in-memory reads from storage
        address _manager = manager;
        address _stableToken = stableToken;
        address _worker = worker;
        address _customer = customer;
        SharedTypes.WorkStatus _currentWorkStatus = workStatus;

        //////////////
        /// CHECKS ///
        //////////////

        // Work status must be IN_QUEUE, IN_PROGRESS, or IN_REVIEW
        if (_currentWorkStatus != SharedTypes.WorkStatus.IN_QUEUE
            && _currentWorkStatus != SharedTypes.WorkStatus.IN_PROGRESS
            && _currentWorkStatus != SharedTypes.WorkStatus.IN_REVIEW
        ) {
            revert InvalidWorkStatus();
        }

        ///////////////
        /// EFFECTS ///
        ///////////////

        // Update the work status
        _setWorkStatus(_currentWorkStatus, SharedTypes.WorkStatus.CANCELED);

        // Update the dispute ruling
        setDisputeRuling(SharedTypes.DisputeRuling.WORKER_AT_FAULT);

        ////////////////////
        /// INTERACTIONS ///
        ////////////////////

        // Create a negative reputation event for the worker
        IGigabitEscrowManager(_manager).increaseWorkerFaultCount(_worker);

        // Get the amount of customer funds locked in the contract
        uint256 _refundAmount = IERC20(_stableToken).balanceOf(address(this));

        // Refund the customer
        if (_refundAmount > 0) {
            IERC20(_stableToken).safeTransfer(_customer, _refundAmount);
        }
    }

    /**
     * @dev Worker can complete the order if they have delivered the work and the customer is not responding
     **/
    function completeDueToCustomerTimeout() external onlyWorker nonReentrant isPaid {
        // Set up in-memory reads from storage
        uint256 _amountDue = amountDue;
        uint256 _serviceFee = serviceFee;
        uint8 _customerTimeoutDays = IGigabitEscrowManager(manager).customerTimeoutDays();
        SharedTypes.WorkStatus _currentWorkStatus = workStatus;

        //////////////
        /// CHECKS ///
        //////////////

        // Work status must be IN_REVIEW
        if (_currentWorkStatus != SharedTypes.WorkStatus.IN_REVIEW) {
            revert InvalidWorkStatus();
        }

        // Scope: Check if the customer has not responded for the configured timeout period
        {
            uint256 _lastUpdateTimestamp = workStatusUpdates[
                workStatusUpdates.length - 1
            ].timestamp;

            if (_lastUpdateTimestamp == 0) {
                revert MissingWorkStatusUpdate();
            }

            if ((_lastUpdateTimestamp + (_customerTimeoutDays * 1 days)) > block.timestamp) {
                revert OrderNotTimedOut();
            }
        }

        ///////////////
        /// EFFECTS ///
        ///////////////

        Split memory _split = _calculateSplit(_amountDue, _serviceFee);

        // Update the work status
        _setWorkStatus(_currentWorkStatus, SharedTypes.WorkStatus.COMPLETED);

        // Update the dispute ruling
        setDisputeRuling(SharedTypes.DisputeRuling.CUSTOMER_AT_FAULT);

        ////////////////////
        /// INTERACTIONS ///
        ////////////////////

        // Transfer the funds
        _transferSplit(_split);
    }

    ///////////////////////////////
    /// CUSTOMER-ONLY FUNCTIONS ///
    ///////////////////////////////

    /**
     * @dev Customer grants the worker's request for more time
     **/
    function acceptExtensionRequest() external onlyCustomer isPaid {
        // Set up in-memory reads from storage
        string memory _orderId = orderId;
        uint8 _extensionRequestDays = extensionRequestDays;
        SharedTypes.WorkStatus _currentWorkStatus = workStatus;

        //////////////
        /// CHECKS ///
        //////////////

        // Work status must be either IN_PROGRESS, or IN_REVIEW
        if (_currentWorkStatus != SharedTypes.WorkStatus.IN_PROGRESS
            && _currentWorkStatus != SharedTypes.WorkStatus.IN_REVIEW
        ) {
            revert InvalidWorkStatus();
        }

        // Extension request must be pending
        if (_extensionRequestDays == 0) {
            revert ExtensionRequestNotPending();
        }

        ///////////////
        /// EFFECTS ///
        ///////////////

        // Add the extension days to the days to complete
        daysToComplete += _extensionRequestDays;

        // Reset the extension request
        extensionRequestDays = 0;

        // Emit the event
        emit ExtensionRequestAccepted(_orderId, _extensionRequestDays);
    }

    /**
     * @dev Customer denies the worker's request for more time
     **/
    function denyExtensionRequest() external onlyCustomer isPaid {
        // Set up in-memory reads from storage
        string memory _orderId = orderId;
        uint8 _extensionRequestDays = extensionRequestDays;
        SharedTypes.WorkStatus _currentWorkStatus = workStatus;

        //////////////
        /// CHECKS ///
        //////////////

        // Work status must be either IN_PROGRESS or IN_REVIEW
        if (_currentWorkStatus != SharedTypes.WorkStatus.IN_PROGRESS
            && _currentWorkStatus != SharedTypes.WorkStatus.IN_REVIEW
        ) {
            revert InvalidWorkStatus();
        }

        // Extension request must be pending
        if (_extensionRequestDays == 0) {
            revert ExtensionRequestNotPending();
        }

        ///////////////
        /// EFFECTS ///
        ///////////////

        // Reset the extension request
        extensionRequestDays = 0;

        // Update the status
        emit ExtensionRequestRejected(_orderId);
    }

    /**
     * @dev Customer accepts worker's current draft
     **/
    function signalAcceptanceOfWork() external onlyCustomer nonReentrant isPaid {
        uint256 _amountDue = amountDue;
        uint256 _serviceFee = serviceFee;
        SharedTypes.WorkStatus _currentWorkStatus = workStatus;

        //////////////
        /// CHECKS ///
        //////////////

        // Work status must be IN_REVIEW
        if (_currentWorkStatus != SharedTypes.WorkStatus.IN_REVIEW) {
            revert InvalidWorkStatus();
        }

        ///////////////
        /// EFFECTS ///
        ///////////////

        Split memory _split = _calculateSplit(_amountDue, _serviceFee);

        // Update the work status
        _setWorkStatus(_currentWorkStatus, SharedTypes.WorkStatus.COMPLETED);

        ////////////////////
        /// INTERACTIONS ///
        ////////////////////

        _transferSplit(_split);
    }

    /**
     * @dev Customer reject's worker's draft
     **/
    function requestRevision() external onlyCustomer isPaid {
        // Set up in-memory reads from storage
        string memory _orderId = orderId;
        uint8 _revisionRequestsLeft = revisionRequestsLeft;
        SharedTypes.WorkStatus _currentWorkStatus = workStatus;

        //////////////
        /// CHECKS ///
        //////////////

        // Work status must be IN_REVIEW
        if (_currentWorkStatus != SharedTypes.WorkStatus.IN_REVIEW) {
            revert InvalidWorkStatus();
        }

        // Can't request a revision if there are no revision requests left
        if (_revisionRequestsLeft == 0) {
            revert RevisionRequestsDepleted();
        }

        ///////////////
        /// EFFECTS ///
        ///////////////

        // Decrement the number of revision requests left
        revisionRequestsLeft--;

        // Update the work status
        _setWorkStatus(_currentWorkStatus, SharedTypes.WorkStatus.IN_PROGRESS);

        // Emit the event
        emit RevisionRequested(_orderId);
    }

    /**
     * @dev Customer has serious issues with the worker's work
     **/
    function disputeDeliverables() external onlyCustomer isPaid {
        // Set up in-memory reads from storage
        string memory _orderId = orderId;
        uint8 _revisionRequestsLeft = revisionRequestsLeft;
        SharedTypes.WorkStatus _currentWorkStatus = workStatus;

        //////////////
        /// CHECKS ///
        //////////////

        // Work status must be IN_REVIEW
        if (_currentWorkStatus != SharedTypes.WorkStatus.IN_REVIEW) {
            revert InvalidWorkStatus();
        }

        // Can't dispute if there are still revision requests left
        if (_revisionRequestsLeft > 0) {
            revert RevisionRequestsAvailable();
        }

        ///////////////
        /// EFFECTS ///
        ///////////////

        // Update the work status
        _setWorkStatus(_currentWorkStatus, SharedTypes.WorkStatus.IN_DISPUTE);

        // Update the dispute ruling
        setDisputeRuling(SharedTypes.DisputeRuling.AWAITING_JUDGMENT);

        // Emit the event
        emit OrderInDispute(_orderId);
    }

    /**
     * @dev Worker or customer has reported the other for bad or abusive behavior
     **/
    function disputeReportedBehavior() external isPaid {

        // Set up in-memory reads from storage
        string memory _orderId = orderId;
        address _worker = worker;
        address _customer = customer;
        address _msgSender = _msgSender();
        SharedTypes.WorkStatus _currentWorkStatus = workStatus;

        //////////////
        /// CHECKS ///
        //////////////

        // Only worker or customer can report the other
        if (_msgSender != _worker 
            && _msgSender != _customer
        ) {
            revert Unauthorized();
        }

        // Work status must be IN_QUEUE, IN_PROGRESS, or IN_REVIEW
        if (_currentWorkStatus != SharedTypes.WorkStatus.IN_QUEUE
            && _currentWorkStatus != SharedTypes.WorkStatus.IN_PROGRESS
            && _currentWorkStatus != SharedTypes.WorkStatus.IN_REVIEW
        ) {
            revert InvalidWorkStatus();
        }

        ///////////////
        /// EFFECTS ///
        ///////////////

        // Update the work status
        _setWorkStatus(_currentWorkStatus, SharedTypes.WorkStatus.IN_DISPUTE);

        // Update the dispute ruling
        setDisputeRuling(SharedTypes.DisputeRuling.AWAITING_JUDGMENT);

        // Set the reported flags
        if (_msgSender == _worker) {
            customerReported = true;
        } else {
            workerReported = true;
        }

        // Emit the event
        emit OrderInDispute(_orderId);
         
        ////////////////////
        /// INTERACTIONS ///
        ////////////////////

        // Create a negative reputation event for the reported party
        address _reportedAddress = _msgSender == _worker ? _customer : _worker;
        IGigabitEscrowManager(manager).reportInOrder(_msgSender, _reportedAddress, _orderId);
    }

    function cancelBeforeWorkStarts() external onlyCustomer nonReentrant isPaid {
        // Set up in-memory reads from storage
        address _stableToken = stableToken;
        address _manager = manager;
        address _customer = customer;
        uint256 _serviceFee = serviceFee;
        uint256 _balance = IERC20(_stableToken).balanceOf(address(this));
        SharedTypes.WorkStatus _currentWorkStatus = workStatus;
        
        //////////////
        /// CHECKS ///
        //////////////

        // Work status must be IN_QUEUE
        if (_currentWorkStatus != SharedTypes.WorkStatus.IN_QUEUE
        ) {
            revert InvalidWorkStatus();
        }

        // Must have enough balance to cover the service fee
        if (_balance < _serviceFee) {
            revert InsufficientBalance(); // should never happen, but just in case
        }

        ///////////////
        /// EFFECTS ///
        ///////////////

        // Calculate the refund amount to the customer (less any service fee)
        uint256 _refundAmount = (serviceFee > 0) ? _balance - _serviceFee : _balance;

        // Update the work status
        _setWorkStatus(_currentWorkStatus, SharedTypes.WorkStatus.CANCELED);

        ////////////////////
        /// INTERACTIONS ///
        ////////////////////

        // Create a negative reputation event for the customer
        IGigabitEscrowManager(_manager).increaseCustomerFaultCount(_customer);

        // Send the service fee to the company
        if (_serviceFee > 0) {
            IERC20(_stableToken).safeTransfer(IGigabitEscrowManager(_manager).owner(), _serviceFee);
        }

        // Refund the customer
        if (_refundAmount > 0) {
            IERC20(_stableToken).safeTransfer(_customer, _refundAmount);
        }
    }

    /**
     * @dev Customer can cancel for a full refund if the worker has not started work within 30 days
     **/
    function cancelDueToNeglect() external onlyCustomer nonReentrant isPaid {
        // Set up in-memory reads from storage
        address _stableToken = stableToken;
        address _manager = manager;
        address _worker = worker;
        address _customer = customer;
        SharedTypes.WorkStatus _currentWorkStatus = workStatus;

        //////////////
        /// CHECKS ///
        //////////////

        // Work status must be IN_QUEUE
        if (_currentWorkStatus != SharedTypes.WorkStatus.IN_QUEUE) {
            revert InvalidWorkStatus();
        }

        if (block.timestamp < startBy + 30 days) {
            revert OrderNotTimedOut();
        }

        ///////////////
        /// EFFECTS ///
        ///////////////

        // Get the amount of customer funds locked in the contract
        uint256 _refundAmount = IERC20(_stableToken).balanceOf(address(this));

        // Update the work status
        _setWorkStatus(_currentWorkStatus, SharedTypes.WorkStatus.CANCELED);

        // Update the dispute ruling
        setDisputeRuling(SharedTypes.DisputeRuling.WORKER_AT_FAULT);

        ////////////////////
        /// INTERACTIONS ///
        ////////////////////

        // Create a negative reputation event for the worker
        IGigabitEscrowManager(_manager).increaseWorkerFaultCount(_worker);

        // Refund the customer
        if (_refundAmount > 0) {
            IERC20(_stableToken).safeTransfer(_customer, _refundAmount);
        }
    }

    /**
     * @dev Customer, worker, or company can cancel if customer doesn't pay within 24 hours of creating the order
     **/
    function cancelDueToNonPayment() external nonReentrant {
        // Set up in-memory reads from storage
        address _stableToken = stableToken;
        address _customer = customer;
        address _worker = worker;
        address _msgSender = _msgSender();
        address _company = IGigabitEscrowManager(manager).owner();
        SharedTypes.WorkStatus _currentWorkStatus = workStatus;

        //////////////
        /// CHECKS ///
        //////////////

        // Order must be unpaid
        if (fullPaymentInContract() == true) {
            revert OrderPaid();
        }

        // Only customer, worker, or company can cancel an unpaid order
        if (_msgSender != _customer &&
            _msgSender != _worker &&
            _msgSender != _company
        ) {
            revert Unauthorized();
        }

        // Order must be late enough to cancel
        if (block.timestamp < queuedAt + 1 days) {
            revert PaymentNotLate();
        }

        if (_currentWorkStatus != SharedTypes.WorkStatus.NONE) {
            revert InvalidWorkStatus(); // should never happen, but just in case
        }

        ///////////////
        /// EFFECTS ///
        ///////////////

        // Get the amount of customer funds locked in the contract
        // It is possible that the customer has paid some amount, but not enough
        uint256 _refundAmount = IERC20(_stableToken).balanceOf(address(this));

        // Update the work status
        _setWorkStatus(_currentWorkStatus, SharedTypes.WorkStatus.CANCELED);

        // Update the dispute ruling
        setDisputeRuling(SharedTypes.DisputeRuling.CUSTOMER_AT_FAULT);

        ////////////////////
        /// INTERACTIONS ///
        ////////////////////

        // Refund the customer (if there is anything to refund)
        if (_refundAmount > 0) {
            IERC20(_stableToken).safeTransfer(_customer, _refundAmount);
        }
    }

    /**
     * @dev Sometimes payment takes too long to arrive; if this happens after the order
     *      has been canceled, this function can be called to refund the customer their
     *      payment without the need to invoke an emergency withdrawal.
     **/
    function refundPaymentAfterOrderIsCanceled() external nonReentrant {
        // Set up in-memory reads from storage
        address _manager = manager;
        address _stableToken = stableToken;
        address _customer = customer;
        address _msgSender = _msgSender();
        address _company = IGigabitEscrowManager(_manager).owner();
        uint256 _contractBalance = IERC20(_stableToken).balanceOf(address(this));
        SharedTypes.WorkStatus _currentWorkStatus = workStatus;

        //////////////
        /// CHECKS ///
        //////////////

        // Only customer or company can refund an already canceled order
        if (_msgSender != _customer
            && _msgSender != _company
        ) {
            revert Unauthorized();
        }

        // Work status must be CANCELED
        if (_currentWorkStatus != SharedTypes.WorkStatus.CANCELED) {
            revert InvalidWorkStatus();
        }

        if (_contractBalance == 0) {
            revert EmptyBalance();
        }

        ////////////////////
        /// INTERACTIONS ///
        ////////////////////

        // Refund the customer
        IERC20(_stableToken).safeTransfer(_customer, _contractBalance);
    }

    //////////////////////////////
    /// COMPANY-ONLY FUNCTIONS ///
    //////////////////////////////

    /**
     * @dev Company can resolve a dispute favoring the customer
     **/
    function resolveDisputeFavoringCustomer() external onlyCompany nonReentrant isPaid {
        // Set up in-memory reads from storage
        address _manager = manager;
        address _stableToken = stableToken;
        address _worker = worker;
        address _customer = customer;
        SharedTypes.WorkStatus _currentWorkStatus = workStatus;

        //////////////
        /// CHECKS ///
        //////////////

        // Work status must be IN_DISPUTE
        if (_currentWorkStatus != SharedTypes.WorkStatus.IN_DISPUTE) {
            revert InvalidWorkStatus();
        }

        // Dispute ruling must be AWAITING_JUDGMENT
        if (disputeRuling != SharedTypes.DisputeRuling.AWAITING_JUDGMENT) {
            revert InvalidDisputeRuling();
        }

        ///////////////
        /// EFFECTS ///
        ///////////////

        // Get the amount of customer funds locked in the contract
        uint256 _refundAmount = IERC20(_stableToken).balanceOf(address(this));

        // Update the work status
        _setWorkStatus(_currentWorkStatus, SharedTypes.WorkStatus.CANCELED);

        // Update the disupute ruling
        setDisputeRuling(SharedTypes.DisputeRuling.WORKER_AT_FAULT);

        ////////////////////
        /// INTERACTIONS ///
        ////////////////////

        // Create a negative reputation event for the worker
        IGigabitEscrowManager(_manager).increaseWorkerFaultCount(_worker);

        // Refund the customer
        if (_refundAmount > 0) {
            IERC20(_stableToken).safeTransfer(_customer, _refundAmount);
        }
    }

    /**
     * @dev Company can resolve a dispute favoring the worker
     **/
    function resolveDisputeFavoringWorker() external onlyCompany nonReentrant isPaid {
        // Set up in-memory reads from storage
        address _manager = manager;
        address _customer = customer;
        uint256 _amountDue = amountDue;
        uint256 _serviceFee = serviceFee;
        string memory _orderId = orderId;
        SharedTypes.WorkStatus _currentWorkStatus = workStatus;
        SharedTypes.DisputeRuling _disputeRuling = disputeRuling;

        //////////////
        /// CHECKS ///
        //////////////

        // Work status must be IN_DISPUTE
        if (_currentWorkStatus != SharedTypes.WorkStatus.IN_DISPUTE) {
            revert InvalidWorkStatus();
        }
        
        // Dispute ruling must be AWAITING_JUDGMENT
        if (_disputeRuling != SharedTypes.DisputeRuling.AWAITING_JUDGMENT) {
            revert InvalidDisputeRuling();
        }

        ///////////////
        /// EFFECTS ///
        ///////////////

        // Split the amount due
        Split memory _split = _calculateSplit(_amountDue, _serviceFee);

        // Update the work status
        _setWorkStatus(_currentWorkStatus, SharedTypes.WorkStatus.COMPLETED);

        // Update the dispute ruling
        setDisputeRuling(SharedTypes.DisputeRuling.CUSTOMER_AT_FAULT);

        // Emit the event
        emit DisputeResolvedFavoringWorker(_orderId);

        ////////////////////
        /// INTERACTIONS ///
        ////////////////////

        // Create a positive reputation event for the worker
        IGigabitEscrowManager(_manager).increaseCustomerFaultCount(_customer);

        // Transfer the funds
        _transferSplit(_split);
    }

    /**
     * @dev Company can resolve a dispute as a compromise
     *
     * @param _percentageToWorker The percentage of the amount due to pay to the worker
     **/
    function resolveDisputeAsCompromise(uint8 _percentageToWorker) external onlyCompany nonReentrant isPaid {
        // Set up in-memory reads from storage
        uint256 _amountDue = amountDue;
        uint256 _serviceFee = serviceFee;
        SharedTypes.WorkStatus _currentWorkStatus = workStatus;

        //////////////
        /// CHECKS ///
        //////////////

        // Work status must be IN_DISPUTE
        if (_currentWorkStatus != SharedTypes.WorkStatus.IN_DISPUTE) {
            revert InvalidWorkStatus();
        }

        // Percentage of payout to worker must be between 1 and 99
        if (_percentageToWorker == 0 || _percentageToWorker >= 100) {
            revert InvalidInput();
        }

        ///////////////
        /// EFFECTS ///
        ///////////////

        // Recalculate the amount due to the worker with the new percentage
        uint256 _modifiedAmountDue = (_amountDue * _percentageToWorker) / 100;

        // Split the modified service fee
        uint256 _modifiedServiceFee = (_serviceFee * _percentageToWorker) / 100;

        // Split the modified amount due
        Split memory _split = _calculateSplit(_modifiedAmountDue, _modifiedServiceFee);

        // Update the work status
        _setWorkStatus(_currentWorkStatus, SharedTypes.WorkStatus.SETTLED);

        // Update the dispute ruling
        setDisputeRuling(SharedTypes.DisputeRuling.COMPROMISE);

        ////////////////////
        /// INTERACTIONS ///
        ////////////////////

        // Transfer the funds
        _transferSplit(_split);
    }

    /**
     * @dev Recovers any orphaned ether that was accidentally sent to this contract
     */
    function recoverOrphanedEther() external onlyCompany nonReentrant {
        // Set up in-memory reads from storage
        address _manager = manager;
        uint256 _contractEthBalance = address(this).balance;

        //////////////
        /// CHECKS ///
        //////////////

        // Contract must have a non-zero balance
        if (_contractEthBalance == 0) {
            revert EmptyBalance();
        }

        ///////////////
        /// EFFECTS ///
        ///////////////

        emit RecoveredOrphanedEther(_contractEthBalance);

        ////////////////////
        /// INTERACTIONS ///
        ////////////////////

        payable(IGigabitEscrowManager(_manager).feeRecipient()).transfer(_contractEthBalance);
        if (address(this).balance > 0) {
            revert TransferFailed();
        }
    }

    /**
     * @dev Recovers any ERC20 tokens that were accidentally sent to this contract
     *      except for the designated stabletoken, that can be withdrawn using the emergencyWithdraw function
     */
    function recoverOrphanedTokens(
        address _token,
        uint256 _amount
    ) external onlyCompany nonReentrant {
        // Set up in-memory reads from storage
        address _manager = manager;
        address _stableToken = stableToken;
        uint256 _contractTokenBalance = IERC20(_token).balanceOf(address(this));

        //////////////
        /// CHECKS ///
        //////////////

        // Cannot withdraw the designated stabletoken
        if (_token == _stableToken) {
            revert RestrictedToken();
        }

        // Contract must have a non-zero balance
        if (_contractTokenBalance == 0) {
            revert EmptyBalance();
        }

        // Cannot withdraw more than the contract balance
        if (_amount > _contractTokenBalance) {
            revert InsufficientBalance();
        }

        ///////////////
        /// EFFECTS ///
        ///////////////

        emit RecoveredOrphanedTokens(_token, _amount);

        ////////////////////
        /// INTERACTIONS ///
        ////////////////////

        IERC20(_token).safeTransfer(
            IGigabitEscrowManager(_manager).feeRecipient(),
            _amount
        );
    }

    /**
     * @dev Starts a 14 day timer to allow the company to withdraw funds from the contract
     */
    function proposeEmergencyWithdraw() external onlyCompany nonReentrant {
        // Set up in-memory reads from storage
        address _stableToken = stableToken;
        string memory _orderId = orderId;
        uint256 _contractBalance = IERC20(_stableToken).balanceOf(address(this));

        //////////////
        /// CHECKS ///
        //////////////

        // Contract must have a non-zero balance
        if (_contractBalance == 0) {
            revert EmptyBalance();
        }

        // Cannot propose an emergency withdrawal if one is already proposed
        if (emergencyWithdrawProposalAt != 0) {
            revert EmergencyWithdrawAlreadyProposed();
        }

        ///////////////
        /// EFFECTS ///
        ///////////////

        emergencyWithdrawProposalAt = uint64(block.timestamp);

        // Set status to terminated
        _setWorkStatus(workStatus, SharedTypes.WorkStatus.TERMINATED);

        // Emit the event
        emit EmergencyWithdrawProposed(_orderId, _contractBalance);
    }

    /**
     * @dev Subject to timelock restrictions, emergency withdraw all funds from the contract
     */
    function emergencyWithdraw() external onlyCompany nonReentrant {
        // Set up in-memory reads from storage
        address _manager = manager;
        address _stableToken = stableToken;
        uint256 _contractBalance = IERC20(_stableToken).balanceOf(address(this));
        string memory _orderId = orderId;

        //////////////
        /// CHECKS ///
        //////////////

        // Contract must have a non-zero balance
        if (_contractBalance == 0) {
            revert EmptyBalance();
        }

        // Cannot withdraw if no emergency withdrawal is proposed
        if (emergencyWithdrawProposalAt == 0) {
            revert EmergencyWithdrawNotProposed();
        }

        // Cannot withdraw if less than 14 days have passed since the proposal
        if (block.timestamp < emergencyWithdrawProposalAt + 14 days) {
            revert TimelockNotExpired();
        }

        ///////////////
        /// EFFECTS ///
        ///////////////

        emergencyWithdrawProposalAt = 0; // Reset the flag

        emit EmergencyWithdraw(_orderId, _contractBalance);

        ////////////////////
        /// INTERACTIONS ///
        ////////////////////

        IERC20(_stableToken).safeTransfer(
            IGigabitEscrowManager(_manager).feeRecipient(),
            _contractBalance
        );
    }

    function fullPaymentInContract() public view returns (bool) {
        return IERC20(stableToken).balanceOf(address(this)) >= amountDue + serviceFee;
    }

    //////////////////////////
    /// INTERNAL FUNCTIONS ///
    //////////////////////////

    /**
     * @dev Checks if an address is an externally owned account (EOA) or a smart contract
     *
     * @param _addressToCheck The address to be checked
     * @return bool TRUE if the address is an EOA, FALSE otherwise
     **/
    function _isEOA(address _addressToCheck) internal view returns (bool) {
        uint256 _codeSize;

        // For the purposes of this function, the zero address is considered an EOA
        // since it is not possible to deploy a contract to the zero address
        if (_addressToCheck == address(0)) {
            return true;
        }

        assembly {
            _codeSize := extcodesize(_addressToCheck)
        }
        return _codeSize == 0;
    }

    /**
     * @dev Sets and logs the work status
     *
     * @param _newWorkStatus The new work status to be logged
     **/
    function _setWorkStatus(
        SharedTypes.WorkStatus _oldWorkStatus,
        SharedTypes.WorkStatus _newWorkStatus
    ) internal {
        // Set up in-memory reads from storage
        address _manager = manager;
        string memory _orderId = orderId;

        //////////////
        /// CHECKS ///
        //////////////

        // Work status must have a valid transition from a transition matrix
        if (IGigabitEscrowManager(_manager).isValidTransition(uint8(_oldWorkStatus), uint8(_newWorkStatus)) == false) {
            revert InvalidWorkStatus();
        }

        ///////////////
        /// EFFECTS ///
        ///////////////

        // Update the work status
        workStatus = _newWorkStatus;

        // Log the work status update
        workStatusUpdates.push(
            SharedTypes.WorkStatusUpdate(block.timestamp, _newWorkStatus)
        );

        // Emit the event
        emit WorkStatusUpdated(_orderId, _newWorkStatus);

        ////////////////////
        /// INTERACTIONS ///
        ////////////////////

        // Update the work status counts in the manager
        IGigabitEscrowManager(_manager).updateStatusStatistics(
            uint8(_oldWorkStatus),
            uint8(_newWorkStatus)
        );
    }

    /**
     * @dev Sets and logs the dispute ruling
     *
     * @param _newDisputeRuling The dispute ruling to be logged
     **/
    function setDisputeRuling(SharedTypes.DisputeRuling _newDisputeRuling) internal {
        // Set up in-memory reads from storage
        address _manager = manager;
        address _customer = customer;
        address _worker = worker;
        string memory _orderId = orderId;

        //////////////
        /// CHECKS ///
        //////////////

        // Dispute ruling must be a valid ruling
        if (_newDisputeRuling == SharedTypes.DisputeRuling.NOT_APPLICABLE  // new ruling cannot be NOT_APPLICABLE
            || _newDisputeRuling == disputeRuling              // new ruling cannot be the same as the old ruling
        ) {
            revert InvalidDisputeRuling();
        }

        ///////////////
        /// EFFECTS ///
        ///////////////

        // Update the dispute ruling
        disputeRuling = _newDisputeRuling;

        // Log the dispute ruling update
        disputeRulingUpdates.push(
            SharedTypes.DisputeRulingUpdate(block.timestamp, _newDisputeRuling)
        );

        // Emit the event
        emit DisputeRulingUpdated(_orderId, _newDisputeRuling);

        ////////////////////
        /// INTERACTIONS ///
        ////////////////////

        if (_newDisputeRuling == SharedTypes.DisputeRuling.WORKER_AT_FAULT) {
            // Create a negative reputation event for the worker
            IGigabitEscrowManager(_manager).increaseWorkerFaultCount(_worker);
        } else if (_newDisputeRuling == SharedTypes.DisputeRuling.CUSTOMER_AT_FAULT) {
            // Create a negative reputation event for the customer
            IGigabitEscrowManager(_manager).increaseCustomerFaultCount(
                _customer
            );
        }
    }

    /**
     * @dev If this contract is launched manually, it can be flagged as an implementation
     **/
    function setAsImplementation() external {
        // Set up in-memory reads from storage
        address _manager = manager;
        bool _isImplementation = isImplementation;

        //////////////
        /// CHECKS ///
        //////////////

        // Check if the contract is already set as an implementation
        if (_isImplementation == true) {
            revert ImplementationAlreadySet();
        }

        // If the manager is set, the contract was initialized and cannot be set as an implementation
        if (_manager != address(0)) {
            revert AlreadyInitialized();
        }

        ///////////////
        /// EFFECTS ///
        ///////////////

        // Set the implementation flag
        isImplementation = true;
        emit ImplementationSet();
    }

    /**
     * @dev Splits the amount awarded to the worker into:
     *       - the company's cut (less the referrer's cut, does NOT include the service fee)
     *       - the worker's cut (less the affiliate's cut)
     *       - the referrer's cut (if applicable)
     *       - the affiliate's cut (if applicable)
     *       - the customer's refund (if applicable, based on excess contract balance)
     *
     * @param _amountAwarded The total gross amount awarded to the worker before deductions
     * @param _serviceFee The service fee to be deducted from the company's cut
     * @return _split The split of the amount due
     **/
    function _calculateSplit(uint256 _amountAwarded, uint256 _serviceFee) internal view returns (Split memory) {

        // Scope: Validate the service fee
        {
            if (_serviceFee > serviceFee) {
                revert InvalidServiceFee(); // should never happen, but just in case
            }
        }

        // Set up in-memory reads from storage
        uint8 _companyPercentageCut = companyPercentageCut;
        uint8 _affiliatePercentageCut = affiliatePercentageCut;
        uint8 _referrerPercentageCut = referrerPercentageCut;
        uint256 _contractBalance = IERC20(stableToken).balanceOf(address(this));

        // Scope: Calculate the company and referrer's cut
        uint256 _amountToCompany;
        uint256 _amountToReferrer;
        {
            // Calculate the company's cut (pre-referrer)
            uint256 _amountToCompanyPreReferrer = (_amountAwarded * _companyPercentageCut) / 100;

            // Calculate the referrer's cut from the company's cut (if applicable)
            _amountToReferrer = (_amountToCompanyPreReferrer * _referrerPercentageCut) / 100;

            // Calculate the company's cut (without the service fee)
            if (_amountToCompanyPreReferrer < _amountToReferrer) {
                revert CompanyCutUnderflow();
            }
            _amountToCompany = _amountToCompanyPreReferrer - _amountToReferrer;
        }

        // Scope: Calculate the worker and affiliate's cut
        uint256 _amountToWorker;
        uint256 _amountToAffiliate;
        {
            // Calculate the worker's cut pre-affiliate
            if (_amountAwarded < (_amountToCompany + _amountToReferrer)) {
                revert WorkerCutUnderflow();
            }
            uint256 _amountToWorkerPreAffiliate = _amountAwarded - _amountToCompany - _amountToReferrer;

            // Calculate the affiliate's cut
            _amountToAffiliate = (_amountToWorkerPreAffiliate * _affiliatePercentageCut) / 100;

            // Calculate the worker's cut
            if (_amountToWorkerPreAffiliate < _amountToAffiliate) {
                revert WorkerFinalCutUnderflow();
            }
            _amountToWorker = _amountToWorkerPreAffiliate - _amountToAffiliate;
        }

        // Add the service fee to the company's cut
        _amountToCompany += _serviceFee;
        
        // Scope: Calculate the potential refund to the customer
        uint256 _amountToCustomer;
        {
            // Calculate the total deductions
            uint256 _totalDeductions = _amountToCompany + _amountToWorker + _amountToAffiliate + _amountToReferrer;

            // Calculate the amount to refund to the customer
            if (_contractBalance < _totalDeductions) {
                revert CustomerCutUnderflow();
            }
            _amountToCustomer = _contractBalance - _totalDeductions;
        }

        // Create the split struct and assign the values
        Split memory _split;
        _split.amountToCompany = _amountToCompany;
        _split.amountToWorker = _amountToWorker;
        _split.amountToCustomer = _amountToCustomer;
        _split.amountToAffiliate = _amountToAffiliate;
        _split.amountToReferrer = _amountToReferrer;

        return _split;
    }

    /**
     * @dev Safely transfer the amount due to the company, worker, customer, affiliate, and referrer
     *
     * @param _split The split of the amount due
     */
    function _transferSplit(Split memory _split) internal {
        // Set up in-memory reads from storage
        address _manager = manager;
        address _stableToken = stableToken;
        address _worker = worker;
        address _customer = customer;
        address _affiliate = affiliate;
        address _referrer = referrer;
        address _company = IGigabitEscrowManager(_manager).feeRecipient();

        // Attempt payment to worker
        if (_split.amountToWorker > 0) {
            IERC20(_stableToken).safeTransfer(_worker, _split.amountToWorker);
        }

        // Attempt payment to affiliate
        if (_split.amountToAffiliate > 0) {
            IERC20(_stableToken).safeTransfer(_affiliate, _split.amountToAffiliate);
        }

        // Attempt payment to referrer
        if (_split.amountToReferrer > 0) {
            IERC20(_stableToken).safeTransfer(_referrer, _split.amountToReferrer);
        }

        // Attempt payment to company
        if (_split.amountToCompany > 0) {
            IERC20(_stableToken).safeTransfer(_company, _split.amountToCompany);
        }

        // Attempt refund to customer
        if (_split.amountToCustomer > 0) {
            IERC20(_stableToken).safeTransfer(_customer, _split.amountToCustomer);
        }
    }

    function devModeSetStatus(SharedTypes.WorkStatus _newWorkStatus) external {
        if (devMode == false) {
            revert DevModeDisabled();
        }
        if (_newWorkStatus == SharedTypes.WorkStatus.NONE) {
            revert InvalidWorkStatus();
        }
        // bypasses all checks and sets the work status
        workStatus = _newWorkStatus;
    }
}
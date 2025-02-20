// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "./openzeppelin_contracts-upgradeable_utils_PausableUpgradeable.sol";
import "./openzeppelin_contracts-upgradeable_access_AccessControlUpgradeable.sol";
import "./openzeppelin_contracts-upgradeable_proxy_utils_Initializable.sol";
import "./openzeppelin_contracts-upgradeable_proxy_utils_UUPSUpgradeable.sol";
import "./openzeppelin_contracts_governance_TimelockController.sol";
import "./openzeppelin_contracts-upgradeable_utils_ReentrancyGuardUpgradeable.sol";
import "./openzeppelin_contracts-upgradeable_token_ERC20_extensions_ERC20BurnableUpgradeable.sol";
import "./openzeppelin_contracts-upgradeable_token_ERC20_extensions_ERC20PausableUpgradeable.sol";
import "./openzeppelin_contracts-upgradeable_token_ERC20_extensions_ERC20PermitUpgradeable.sol";
import "./openzeppelin_contracts-upgradeable_token_ERC20_extensions_ERC20VotesUpgradeable.sol";
import "./openzeppelin_contracts-upgradeable_token_ERC1155_extensions_ERC1155PausableUpgradeable.sol";
import "./openzeppelin_contracts-upgradeable_token_ERC1155_extensions_ERC1155BurnableUpgradeable.sol";
import "./openzeppelin_contracts-upgradeable_token_ERC1155_extensions_ERC1155SupplyUpgradeable.sol";
import "./hardhat_console.sol";
import "./contracts_rewards_RewardSystem.sol";

interface ISyraxValidation {
    enum Outcome { Undecided, Yes, No, Unresolved }
    enum MarketState { Open, Validated, InDispute, Settled }
    function getMarketOutcome(uint256 marketId) external view returns (Outcome, MarketState, address[] memory, address);
}

/// @custom:security-contact hello@syrax.au
contract MasterV2 is Initializable, PausableUpgradeable, AccessControlUpgradeable, UUPSUpgradeable, ReentrancyGuardUpgradeable, RewardSystem {
    bytes32 public constant PAUSER_ROLE = keccak256("PAUSER_ROLE");
    bytes32 public constant UPGRADER_ROLE = keccak256("UPGRADER_ROLE");
    bytes32 public constant MARKET_BUILDER_ROLE = keccak256("MARKET_BUILDER_ROLE");
    bytes32 public constant MARKET_VALIDATOR_ROLE = keccak256("MARKET_VALIDATOR_ROLE");
    bytes32 public constant URI_SETTER_ROLE = keccak256("URI_SETTER_ROLE");

    // address public immutable owner;
    uint public marketCount;
    uint public totalContractCount;
    address public treasury;
    uint public marketFee;
    uint public platformFee;
    uint public validatorFee;

    struct Share {
        address owner;
        uint256 amount;
        bool position;
    }

    
    struct Contract {
        uint256 id;
        string name;
        bool isClosed;
        bool isSettled;
        int outcome;
        bool isVerified;
        bool isDisputed;
        uint256 shareNumbers;
        uint256 totalSharesValue;
        uint256 yesSharesValue;
        uint256 noSharesValue;
        bool isCancelled;
        uint netRemaining;
        mapping(address => uint256) yesShareAmounts;
        mapping(address => uint256) noShareAmounts;
        mapping(address => bool) hasClaimed;
        mapping(address => bool) isParticipant;
        address[] participantAddresses;
        mapping(address => uint) payouts;
    }


    struct Market{
        uint256 id;
        string name;
        string description;
        string category;
        uint contractCount;
        string oracle;
        address owner;
        uint256 endTime;
        uint256 validationTime;
        uint256 startingLiquidity;
        string marketRef;
        string imageUrl;
        bool isCancelled;
        mapping(uint256 => Contract) contracts;
    }


    struct MarketStatus {
        bool isClosed;
        int outcome;
        bool isVerified;
        bool isSettled;
    }

    mapping(uint256 => Market) public markets;

    ISyraxValidation public validator;
    
    

    event MarketBuilderAuthorized(address _marketBuilder);
    event MarketBuilderUnAuthorized(address _marketBuilder);
    event MarketValidatorAuthorized(address _marketValidator);
    event MarketValidatorUnAuthorized(address _marketValidator);
    event MarketCreated(uint256 indexed marketId, string name,uint endTime, uint startingLiquidity,string oracle,string marketRef, address indexed marketBuilder, uint validationTime, string category, string imageUrl);
    event MarketClosed(uint256 indexed marketId, uint256 indexed contractId);
    event MarketVerified(uint256 indexed marketId, uint256 indexed contractId, int outcome);
    event SharesPurchased(uint256 indexed marketId, uint256 indexed contractId, address indexed buyer, uint256 amount, bool position);
    event MarketSettled(uint256 indexed marketId, uint256 indexed contractId);
    event PayoutClaimed(uint256 indexed marketId, uint256 indexed contractId, address indexed claimer, uint256 amount, uint timestamp);
    event ValidationAdded(uint256 indexed marketId, uint256 indexed contractId, address indexed validator, bool outcome);
    event MarketCancelled(uint256 indexed marketId, uint256 indexed contractId, uint timestamp);
    event BuilderRefunded(uint256 indexed marketId, uint256 indexed contractId, uint256 amount);
    event MarketFlagged(uint256 indexed marketId, uint256 indexed contractId,uint timestamp, address indexed flagger);
    event BuilderFeePaid(uint256 indexed marketId, uint256 indexed contractId,uint timestamp, address indexed builder, uint amount);
    event ValidatorFeePaid(uint256 indexed marketId, uint256 indexed contractId,uint timestamp, address indexed validator, uint amount);

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

   function initialize(address defaultAdmin, address pauser, address upgrader,  address _rewardToken, address _rewardNFT, address _treasury)
        initializer public
    {
        __Pausable_init();
        __AccessControl_init();
        __UUPSUpgradeable_init();
        __ReentrancyGuard_init();

        
        RewardSystem.setAddresses(_rewardToken, _rewardNFT);
        
        marketCount = 0;
        totalContractCount = 0;
        marketFee = 1;
        platformFee = 4;
        validatorFee = 1;

        // Builder Thresholds
        BUILDER_BRONZE_THRESHOLD = 1;
        BUILDER_SILVER_THRESHOLD = 10;
        BUILDER_GOLD_THRESHOLD = 20;
        BUILDER_PLATINUM_THRESHOLD = 40;
        BUILDER_DIAMOND_THRESHOLD = 80;
        // Builder Rewards
        BRONZE_REWARD = 500 * 10 ** 18;
        SILVER_REWARD = 1000 * 10 ** 18;
        GOLD_REWARD = 2000 * 10 ** 18;
        PLATINUM_REWARD = 4000 * 10 ** 18;
        DIAMOND_REWARD = 8000 * 10 ** 18;
        // User Thresholds
        USER_WHITE_THRESHOLD = 1;
        USER_YELLOW_THRESHOLD = 100;
        USER_ORANGE_THRESHOLD = 200;
        USER_RED_THRESHOLD = 400;
        USER_PURPLE_THRESHOLD = 800;
        // User Rewards
        WHITE_REWARD = 250 * 10 ** 18;
        YELLOW_REWARD = 1000 * 10 ** 18;
        ORANGE_REWARD = 2000 * 10 ** 18;
        RED_REWARD = 4000 * 10 ** 18;
        PURPLE_REWARD = 8000 * 10 ** 18;


        
        treasury = _treasury;

        _grantRole(DEFAULT_ADMIN_ROLE, defaultAdmin);
        _grantRole(PAUSER_ROLE, pauser);
        _grantRole(UPGRADER_ROLE, upgrader);
        _grantRole(MARKET_BUILDER_ROLE, defaultAdmin);
        _grantRole(MARKET_VALIDATOR_ROLE, defaultAdmin);
    }

    function pause()  public onlyRole(PAUSER_ROLE) {
        _pause();
    }

    function unpause() public onlyRole(PAUSER_ROLE) {
        _unpause();
    }

    function _authorizeUpgrade(address newImplementation)
        internal
        onlyRole(UPGRADER_ROLE)
        override
    {}

    modifier onlyValidatorContract() {
        require(msg.sender == address(validator), "Only validator contract can call this function");
        _;
    }

    function _authorizeMarketBuilder(address _marketBuilder) public onlyRole(DEFAULT_ADMIN_ROLE) {
        _grantRole(MARKET_BUILDER_ROLE, _marketBuilder);
        emit MarketBuilderAuthorized(_marketBuilder);
    }

      function _unAuthorizeMarketBuilder(address _marketBuilder) public onlyRole(DEFAULT_ADMIN_ROLE) {
        _revokeRole(MARKET_BUILDER_ROLE, _marketBuilder);
        emit MarketBuilderUnAuthorized(_marketBuilder);
    }

    function _authorizeMarketValidator(address _marketValidator) public onlyRole(DEFAULT_ADMIN_ROLE) {
        _grantRole(MARKET_VALIDATOR_ROLE, _marketValidator);
        emit MarketValidatorAuthorized(_marketValidator);
    }

    function _unAuthorizeMarketValidator(address _marketValidator) public onlyRole(DEFAULT_ADMIN_ROLE) {
        _revokeRole(MARKET_VALIDATOR_ROLE, _marketValidator);
        emit MarketValidatorUnAuthorized(_marketValidator);
    }

       function createMarket(string memory _marketRef,string memory _name, string memory _oracle, uint _endTime, uint _amount, string memory _imageUrl, uint _validationTime, string memory _category, string memory _description) public payable whenNotPaused returns (uint) {
        require(bytes(_name).length > 0, "Market name cannot be empty");
        require(bytes(_oracle).length > 0, "Oracle address cannot be empty");
        require(_endTime > block.timestamp, "End time must be in the future");
        require(_amount > 0, "Amount must be greater than 0");
        require(msg.value == _amount, "Incorrect amount sent $");
        
        marketCount++;

        Market storage market = markets[marketCount];
        market.id = marketCount;
        market.name = _name;
        market.oracle = _oracle;
        market.owner = msg.sender;
        market.endTime = _endTime;
        market.startingLiquidity = _amount;
        market.marketRef = _marketRef;
        market.imageUrl = _imageUrl;
        market.validationTime = _validationTime;
        market.category = _category;
        market.description = _description;
        
    
        totalContractCount++;
        market.contractCount++;

        Contract storage contractInstance = market.contracts[market.contractCount];
        contractInstance.id = totalContractCount;
        contractInstance.name = _name;
        contractInstance.isClosed = false;
        contractInstance.isSettled = false;
        contractInstance.isVerified = false;
        contractInstance.outcome = -1;
        contractInstance.totalSharesValue = _amount;


        // Add initial liquidity equally to both positions
        uint256 halfAmount = _amount / 2;
        uint256 remainder = _amount - (halfAmount * 2);

        // Add initial liquidity to Yes position
        contractInstance.yesSharesValue = halfAmount + remainder;
        contractInstance.yesShareAmounts[msg.sender] = halfAmount + remainder;

        // Add initial liquidity to No position
        contractInstance.noSharesValue = halfAmount;
        contractInstance.noShareAmounts[msg.sender] = halfAmount;

        // Add market owner to participants
        contractInstance.participantAddresses.push(msg.sender);
        contractInstance.isParticipant[msg.sender] = true;
        
        contractInstance.shareNumbers++;
        
        
        emit SharesPurchased(marketCount, market.contractCount , msg.sender, halfAmount + remainder, true);
        emit SharesPurchased(marketCount, market.contractCount , msg.sender, halfAmount, false);


        contractInstance.shareNumbers++;
        
        RewardSystem.recordMarketCreation(msg.sender);

        emit MarketCreated(marketCount, market.name, market.endTime, market.startingLiquidity, market.oracle, market.marketRef, msg.sender,  market.validationTime, market.category, market.imageUrl);

        return marketCount;
    }

    function getMarketStatus(uint _marketId, uint _contractId) public view returns (MarketStatus memory){
        require(_marketId > 0 && _contractId >0 , "Invalid market or contract id");
        Contract storage contractInstance = markets[_marketId].contracts[_contractId];
        MarketStatus memory status = MarketStatus(contractInstance.isClosed, contractInstance.outcome, contractInstance.isVerified, contractInstance.isSettled);
        return status;
    }

    function addContractToMarket(uint _marketId, string memory _name) public onlyRole(MARKET_BUILDER_ROLE) returns (uint){
        Market storage market = markets[_marketId];
        require(market.owner == msg.sender || hasRole(DEFAULT_ADMIN_ROLE, msg.sender), "Not the market owner or admin");
        totalContractCount++;
        market.contractCount++;
        Contract storage contractInstance = market.contracts[market.contractCount];
        contractInstance.id = totalContractCount;
        contractInstance.name = _name;
        contractInstance.isClosed = false;
        contractInstance.isSettled = false;
        contractInstance.isVerified = false;
        contractInstance.outcome = -1;
        return totalContractCount;
    }


   
    function buyShares(uint _marketId, uint _contractId, bool _position, uint _amount) public payable nonReentrant whenNotPaused 
     {
        Contract storage contractInstance = markets[_marketId].contracts[_contractId];
        Market storage marketInstance = markets[_marketId];
        require(!contractInstance.isClosed, "Market is already closed");
        require(!contractInstance.isSettled, "Market is already settled");
        require(_amount > 0, "Amount must be greater than 0");
        require(msg.value == _amount, "Incorrect amount sent $");
        require(block.timestamp < marketInstance.endTime, "Market is closed for trading");

        contractInstance.shareNumbers++;
        contractInstance.totalSharesValue += _amount;

        if (_position) {
            contractInstance.yesSharesValue += _amount;
            contractInstance.yesShareAmounts[msg.sender] += _amount;
        } else {
            contractInstance.noSharesValue += _amount;
            contractInstance.noShareAmounts[msg.sender] += _amount;
        }

        if (!contractInstance.isParticipant[msg.sender]) {
            contractInstance.participantAddresses.push(msg.sender);
            contractInstance.isParticipant[msg.sender] = true;
        }

        RewardSystem.recordPrediction(msg.sender);

        emit SharesPurchased(_marketId, _contractId, msg.sender, _amount, _position);
    }

    function getShares(
        uint256 _marketId,
        uint256 _contractId,
        address _owner,
        bool _position
    ) public view returns (uint256) {
        Contract storage contractInstance = markets[_marketId].contracts[_contractId];
        if (_position) {
            return contractInstance.yesShareAmounts[_owner];
        } else {
            return contractInstance.noShareAmounts[_owner];
        }
        }

    
    function getMarketTotalShares(uint _marketId, uint _contractId) public view returns (uint) {
        Contract storage contractInstance = markets[_marketId].contracts[_contractId];
        return contractInstance.totalSharesValue;
    }

      function settleMarket(uint _marketId, uint _contractId, int _outcome, address[] calldata validators) internal {
        Market storage market = markets[_marketId];
        Contract storage contractInstance = markets[_marketId].contracts[_contractId];
        require(contractInstance.isClosed, "Market is not closed yet");
        require(contractInstance.isVerified, "Market is not verified yet");
        require(contractInstance.outcome == _outcome, "Outcome does not match");
        require(!contractInstance.isSettled, "Market is already settled");
        
        contractInstance.isSettled = true;

         // Calculate and distribute fees
        uint256 totalSharesValue = contractInstance.totalSharesValue;
        uint256 marketFees = (totalSharesValue * marketFee) / 100;
        uint256 platformFees = (totalSharesValue * platformFee) / 100;
        uint256 validatorPayout = (totalSharesValue * validatorFee) / 100;
        uint256 netRemaining = totalSharesValue - marketFees - platformFees - validatorPayout;

        // Transfer fees
        // Transfer market fees to market owner
        (bool successMarketFee, ) = payable(market.owner).call{value: marketFees}("");
        require(successMarketFee, "Transfer to market owner failed");
        emit BuilderFeePaid(_marketId, _contractId, block.timestamp, market.owner, marketFees);

        // Transfer platform fees to treasury
        (bool successPlatformFee, ) = payable(treasury).call{value: platformFees}("");
        require(successPlatformFee, "Transfer to treasury failed");

        // Distribute validator fees
        uint256 validatorShare = validatorPayout / validators.length;
        for (uint256 i = 0; i < validators.length; i++) {
            (bool successValidatorFee, ) = payable(validators[i]).call{value: validatorShare}("");
            require(successValidatorFee, "Transfer to validator failed");
            RewardSystem.recordValidation(validators[i]);
            emit ValidatorFeePaid(_marketId, _contractId, block.timestamp, validators[i], validatorShare);
        }

        // Update net remaining amount
        contractInstance.netRemaining = netRemaining;

        // Reset total shares value to prevent re-use
        contractInstance.totalSharesValue = 0;
        
        
        emit MarketSettled(_marketId, _contractId);
    }

    function getMarketPayout(uint _marketId, uint _contractId, address _participant) public view returns (uint256) {
        Market storage market = markets[_marketId];
        Contract storage contractInstance = markets[_marketId].contracts[_contractId];
        require(contractInstance.isSettled || contractInstance.isCancelled, "Market is neither settled nor cancelled");

        // Check if the participant has already claimed their payout
        if (contractInstance.hasClaimed[_participant]) {
            return 0;
        }

        uint256 shareAmount;

        if (contractInstance.isCancelled) {
            // Refund both Yes and No shares
            shareAmount = contractInstance.yesShareAmounts[_participant] + contractInstance.noShareAmounts[_participant];
        } else {
            // Determine the market outcome
            bool result = contractInstance.outcome == 1;
            shareAmount = result ? contractInstance.yesShareAmounts[_participant] : contractInstance.noShareAmounts[_participant];
        }

        require(shareAmount > 0, "No shares to claim payout for");

         uint256 totalCorrectValue = contractInstance.isCancelled
        ? contractInstance.totalSharesValue - market.startingLiquidity
        : (contractInstance.outcome == 1 ? contractInstance.yesSharesValue : contractInstance.noSharesValue);

        uint256 individualPayout = (contractInstance.netRemaining * shareAmount) / totalCorrectValue;

        return individualPayout;
    }

    function claimPayout(uint _marketId, uint _contractId) public nonReentrant whenNotPaused {
        Contract storage contractInstance = markets[_marketId].contracts[_contractId];

        require(contractInstance.isSettled || contractInstance.isCancelled, "Market is neither settled nor cancelled");
        require(!contractInstance.hasClaimed[msg.sender], "Payout already claimed");
        
        uint256 individualPayout = getMarketPayout(_marketId, _contractId, msg.sender);
        require(individualPayout > 0, "No payout available");
        
        contractInstance.hasClaimed[msg.sender] = true;

        (bool success, ) = payable(msg.sender).call{value: individualPayout}("");
        require(success, "Transfer failed");
        emit PayoutClaimed(_marketId, _contractId, msg.sender, individualPayout, block.timestamp);
    }

/// setValidationResult is called from validator contract to set the validation result
/// @param marketId Market Id
/// @param contractId Contract Id
/// @param outcome The market outcome
/// @param _validatorAddress the validator address
    function setValidationResult(uint256 marketId, uint contractId, ISyraxValidation.Outcome outcome, address[] calldata _validatorAddress) external onlyValidatorContract {
        Market storage market = markets[marketId];
        Contract storage contractInstance = markets[marketId].contracts[contractId];
        require(!contractInstance.isVerified, "Market is already verified");       
        
        contractInstance.isClosed = true;
        contractInstance.isVerified = true;
        
        if (outcome == ISyraxValidation.Outcome.Yes) {
            contractInstance.outcome = 1;
            settleMarket(marketId, contractId, 1, _validatorAddress);

        } else if (outcome == ISyraxValidation.Outcome.No) {
            contractInstance.outcome = 0;
            settleMarket(marketId, contractId, 0, _validatorAddress);
        } else if (outcome == ISyraxValidation.Outcome.Undecided) {
            contractInstance.outcome = -2;
            cancelMarket(marketId, contractId);
        } else if (outcome == ISyraxValidation.Outcome.Unresolved) {
            contractInstance.outcome = -3;
            cancelMarket(marketId, contractId);
        }
        
        emit MarketVerified(marketId, contractId, contractInstance.outcome);
    }

    function setMarketDisputed( uint _marketId, uint _contractId) external onlyValidatorContract {
        Contract storage contractInstance = markets[_marketId].contracts[_contractId];
        require(!contractInstance.isDisputed, "Market is already disputed");
        contractInstance.isDisputed = true;
    }

    function setMarketFee(uint _fee) public onlyRole(DEFAULT_ADMIN_ROLE) {
        marketFee = _fee;
    }

    function setPlatformFee(uint _fee) public onlyRole(DEFAULT_ADMIN_ROLE) {
        platformFee = _fee;
    }

    function setValidatorFee(uint _fee) public onlyRole(DEFAULT_ADMIN_ROLE) {
        validatorFee = _fee;
    }

    function getValidatorFee() public view returns (uint) {
        return validatorFee;
    }

    function setTreasury(address _treasury) public onlyRole(DEFAULT_ADMIN_ROLE) {
        treasury = _treasury;
    }

     function setBuilderRewardsThresholds(BuilderThresholds memory thresholds) public onlyRole(DEFAULT_ADMIN_ROLE) {
        BUILDER_BRONZE_THRESHOLD = thresholds.BUILDER_BRONZE_THRESHOLD;
        BUILDER_SILVER_THRESHOLD = thresholds.BUILDER_SILVER_THRESHOLD;
        BUILDER_GOLD_THRESHOLD = thresholds.BUILDER_GOLD_THRESHOLD;
        BUILDER_PLATINUM_THRESHOLD = thresholds.BUILDER_PLATINUM_THRESHOLD;
        BUILDER_DIAMOND_THRESHOLD = thresholds.BUILDER_DIAMOND_THRESHOLD;
    }

    function setTraderRewardsThresholds(TraderThresholds memory thresholds) public onlyRole(DEFAULT_ADMIN_ROLE) {
        USER_WHITE_THRESHOLD = thresholds.USER_WHITE_THRESHOLD;
        USER_YELLOW_THRESHOLD = thresholds.USER_YELLOW_THRESHOLD;
        USER_ORANGE_THRESHOLD = thresholds.USER_ORANGE_THRESHOLD;
        USER_RED_THRESHOLD = thresholds.USER_RED_THRESHOLD;
        USER_PURPLE_THRESHOLD = thresholds.USER_PURPLE_THRESHOLD;
    }

    function setBuilderRewards(BuilderRewards memory rewards) public onlyRole(DEFAULT_ADMIN_ROLE) {
        BRONZE_REWARD = rewards.BRONZE_REWARD;
        SILVER_REWARD = rewards.SILVER_REWARD;
        GOLD_REWARD = rewards.GOLD_REWARD;
        PLATINUM_REWARD = rewards.PLATINUM_REWARD;
        DIAMOND_REWARD = rewards.DIAMOND_REWARD;
    }

    function setTraderRewards(TraderRewards memory rewards) public onlyRole(DEFAULT_ADMIN_ROLE) {
        WHITE_REWARD = rewards.WHITE_REWARD;
        YELLOW_REWARD = rewards.YELLOW_REWARD;
        ORANGE_REWARD = rewards.ORANGE_REWARD;
        RED_REWARD = rewards.RED_REWARD;
        PURPLE_REWARD = rewards.PURPLE_REWARD;
    }

    function getSharesCount(uint _marketId, uint _contractId) public view returns (uint) {
        return markets[_marketId].contracts[_contractId].shareNumbers;
    }


    function cancelMarket(uint256 _marketId, uint256 _contractId) public onlyRole(DEFAULT_ADMIN_ROLE) {
        Market storage market = markets[_marketId];
        Contract storage contractInstance = market.contracts[_contractId];

        require(!contractInstance.isCancelled, "Market is already cancelled");
        require(!contractInstance.isSettled, "Market is already settled");

        contractInstance.isCancelled = true;
        contractInstance.isClosed = true;
        contractInstance.isVerified = true;
        contractInstance.isSettled = true;

        uint256 totalRefund = contractInstance.totalSharesValue;

        // Refund market creator's starting liquidity
        uint256 builderRefund = market.startingLiquidity;
        (bool successBuilderRefund, ) = payable(market.owner).call{value: builderRefund}("");
        require(successBuilderRefund, "Refund to market owner failed");
        emit BuilderRefunded(_marketId, _contractId, builderRefund);

        totalRefund -= builderRefund;

        // Participants can claim refunds through claimPayout
        contractInstance.netRemaining = totalRefund;

        emit MarketCancelled(_marketId, _contractId, block.timestamp);
        }


/// 
/// @param _marketId The market id
/// @param _contractId The contract id
/// @return market Name
/// @return Contract Total Pool Value
/// @return Market End Time
/// @return Market Owner
    function getMarketDetails(uint _marketId, uint _contractId) public view returns (string memory, uint, uint, address, uint) {
        Contract storage contractInstance = markets[_marketId].contracts[_contractId];
        return (contractInstance.name, contractInstance.totalSharesValue, markets[_marketId].endTime, markets[_marketId].owner, markets[_marketId].validationTime);
    }

/// 
/// @param _validator The address of the validator contract
    function setValidatorContract(address _validator) public onlyRole(DEFAULT_ADMIN_ROLE) {
        validator = ISyraxValidation(_validator);
    }


    function updateMarketMetadata(uint _marketId, string memory _name, string memory _imageUrl, string memory _category) public onlyRole(DEFAULT_ADMIN_ROLE) {
        Market storage market = markets[_marketId];
        market.name = _name;
        market.imageUrl = _imageUrl;
        market.category = _category;
    }

    uint256[50] private __gap;
}

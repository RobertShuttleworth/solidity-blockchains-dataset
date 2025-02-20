// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

import "./openzeppelin_contracts-upgradeable_security_ReentrancyGuardUpgradeable.sol";
import "./openzeppelin_contracts-upgradeable_access_OwnableUpgradeable.sol";
import "./openzeppelin_contracts-upgradeable_security_PausableUpgradeable.sol";
import "./openzeppelin_contracts-upgradeable_token_ERC20_IERC20Upgradeable.sol";
import "./openzeppelin_contracts-upgradeable_token_ERC20_utils_SafeERC20Upgradeable.sol";
import "./openzeppelin_contracts_utils_math_SafeMath.sol";
import "./contracts_interfaces_ITokenEscrow.sol";
import "./contracts_interfaces_IPriceOracle.sol";

/**
 * @title PresaleManager
 * @dev Manages token presale with flexible tier, KYC, and whitelist requirements
 */
contract PresaleManager is
    Initializable,
    ReentrancyGuardUpgradeable,
    OwnableUpgradeable,
    PausableUpgradeable
{
    using SafeERC20Upgradeable for IERC20Upgradeable;
    using SafeMath for uint256;

    struct Tier {
        uint256 price; // Price in USD (6 decimals)
        uint256 minPurchase; // Minimum purchase amount
        uint256 maxPurchase; // Maximum purchase amount
        uint256 maxTokens; // Maximum tokens for this tier
        uint256 soldTokens; // Tokens sold in this tier
        uint256 vestingPeriod; // Vesting period in seconds
        uint256 startTime; // Tier start time
        uint256 endTime; // Tier end time
        bool isActive; // Whether this tier is active
    }

    struct Round {
        uint256 roundId;
        uint256 price; // Price in same decimals as defaultTokenPrice (8 decimals)
        uint256 targetAmount; // Target amount in USD
        uint256 amountRaised; // Amount raised in USD
        uint256 endTime; // When this round ends
        bool isActive; // If this round is currently active
        uint256 startTime; // When this round starts
    }

    struct UserInfo {
        uint256 totalPurchased; // Total tokens purchased
        uint256 totalInvested; // Total amount invested in USD
        uint256[] tiersPurchased; // Array of tier indices user has purchased from
        bool hasKYC; // KYC status
        uint256 lastPurchaseTime; // Last purchase timestamp
        uint256 unclaimedTokens; // Tokens available for direct withdrawal
    }

    // State variables
    IERC20Upgradeable public saleToken;
    IERC20Upgradeable public usdtToken;
    ITokenEscrow public escrow;
    IPriceOracle public priceOracle;

    mapping(uint256 => Tier) public tiers;
    mapping(address => UserInfo) public users;
    mapping(address => bool) public whitelist;
    mapping(address => uint256) public userCaps;

    uint256 public startTime;
    uint256 public endTime;
    uint256 public totalTiers;
    uint256 public totalTokensSold;
    uint256 public totalRaised;
    uint256 public minPurchaseInterval;
    uint256 public maxTokensPerUser;
    uint256 public defaultTokenPrice;
    

    bytes32 public merkleRoot;
    address public treasury;
    address public admin;

    // Control flags
    bool public isWhitelistRequired;
    bool public isKYCRequired;
    bool public isTierRequired;
    bool public allowDirectWithdraw;

    uint256 public constant PRICE_DECIMALS = 8;

    // Events
    event TierAdded(
        uint256 indexed tierId,
        uint256 price,
        uint256 maxTokens,
        uint256 startTime,
        uint256 endTime
    );
    event TokensPurchased(
        address indexed buyer,
        uint256 indexed tierId,
        uint256 amount,
        uint256 price,
        string currency,
        uint256 timestamp
    );
    event KYCStatusUpdated(address indexed user, bool status);
    event WhitelistUpdated(address indexed user, bool status);
    event TreasuryUpdated(
        address indexed oldTreasury,
        address indexed newTreasury
    );
    event AdminUpdated(address indexed oldAdmin, address indexed newAdmin);
    event UserCapUpdated(address indexed user, uint256 newCap);
    event WithdrawControlUpdated(bool allowed);
    event RequirementControlsUpdated(
        bool whitelistRequired,
        bool kycRequired,
        bool tierRequired
    );
    event TokensWithdrawn(address indexed user, uint256 amount);
    event DefaultPriceUpdated(uint256 oldPrice, uint256 newPrice);
    event RoundCreated(
        uint256 indexed roundId,
        uint256 price,
        uint256 targetAmount,
        uint256 endTime,
        uint256 startTime
    );
    event RoundUpdated(
        uint256 indexed roundId,
        uint256 price,
        uint256 targetAmount,
        uint256 endTime,
        uint256 startTime
    );
    event RoundStatusChanged(uint256 indexed roundId, bool isActive);
    event RoundTargetReached(uint256 indexed roundId, uint256 finalAmount);

    // Modifiers
    modifier onlyDuringSale() {
        require(
            block.timestamp >= startTime && block.timestamp <= endTime,
            "Sale not active"
        );
        _;
    }

    modifier checkRequirements(address user) {
        if (isWhitelistRequired) {
            require(whitelist[user], "Not whitelisted");
        }
        if (isKYCRequired) {
            require(users[user].hasKYC, "KYC not completed");
        }
        _;
    }

    modifier onlyAdminOrOwner() {
        require(msg.sender == owner() || msg.sender == admin, "Not authorized");
        _;
    }

    mapping(uint256 => Round) public rounds;
    uint256 public currentRound;
    uint256 public totalRounds;

    function initialize(
        address _saleToken,
        address _usdtToken,
        address _escrow,
        address _priceOracle,
        address _treasury,
        address _admin,
        uint256 _startTime,
        uint256 _endTime
    ) public initializer {
        __Ownable_init();
        __Pausable_init();
        __ReentrancyGuard_init();

        require(_saleToken != address(0), "Invalid sale token");
        require(_usdtToken != address(0), "Invalid USDT token");
        require(_escrow != address(0), "Invalid escrow");
        require(_treasury != address(0), "Invalid treasury");
        require(_admin != address(0), "Invalid admin");
        require(_startTime > block.timestamp, "Invalid start time");
        require(_endTime > _startTime, "Invalid end time");

        saleToken = IERC20Upgradeable(_saleToken);
        usdtToken = IERC20Upgradeable(_usdtToken);
        escrow = ITokenEscrow(_escrow);
        priceOracle = IPriceOracle(_priceOracle);
        treasury = _treasury;
        admin = _admin;
        startTime = _startTime;
        endTime = _endTime;

        // Initialize control flags
        isWhitelistRequired = false;
        isKYCRequired = false;
        isTierRequired = false;
        allowDirectWithdraw = true;
        defaultTokenPrice = 10000000; // $0.10 with 8 decimals
        minPurchaseInterval = 0;
    }

    // Round Management Functions
    function createRound(
        uint256 _price,
        uint256 _targetAmount,
        uint256 _endTime,
        uint256 _startTime
    ) external onlyAdminOrOwner {
        require(_price > 0, "Invalid price");
        require(_targetAmount > 0, "Invalid target amount");
        require(_endTime > block.timestamp, "Invalid end time");

        // Deactivate current round if exists
        if (totalRounds > 0) {
            rounds[currentRound].isActive = false;
            emit RoundStatusChanged(currentRound, false);
        }

        uint256 roundId = totalRounds++;
        currentRound = roundId;

        rounds[roundId] = Round({
            roundId: roundId,
            price: _price,
            targetAmount: _targetAmount,
            amountRaised: 0,
            endTime: _endTime,
            startTime: _startTime,
            isActive: true
        });

        // Update the default token price to match the round price
        defaultTokenPrice = _price;
        emit DefaultPriceUpdated(defaultTokenPrice, _price);
        emit RoundCreated(roundId, _price, _targetAmount, _endTime, _startTime);
    }

    function updateRound(
        uint256 _roundId,
        uint256 _price,
        uint256 _targetAmount,
        uint256 _endTime,
        uint256 _startTime
    ) external onlyAdminOrOwner {
        require(_roundId < totalRounds, "Invalid round");
        Round storage round = rounds[_roundId];
        require(round.isActive, "Round not active");
        require(_price > 0, "Invalid price");
        require(_targetAmount > 0, "Invalid target amount");
        require(_endTime > block.timestamp, "Invalid end time");
        require(_startTime > block.timestamp, "Invalid end time");

        round.price = _price;
        round.targetAmount = _targetAmount;
        round.endTime = _endTime;
        round.startTime = _startTime;

        // Update default price if this is the current round
        if (_roundId == currentRound) {
            defaultTokenPrice = _price;
            emit DefaultPriceUpdated(defaultTokenPrice, _price);
        }

        emit RoundUpdated(_roundId, _price, _targetAmount, _endTime, _startTime);
    }

    // View Functions for Rounds
    function getCurrentRound()
        external
        view
        returns (
            uint256 roundId,
            uint256 price,
            uint256 targetAmount,
            uint256 amountRaised,
            uint256 roundEndTime,
            uint256 roundStartTime,
            bool isActive,
            uint256 timeRemaining
        )
    {
        Round storage round = rounds[currentRound];
        timeRemaining = block.timestamp >= round.endTime
            ? 0
            : round.endTime - block.timestamp;

        return (
            round.roundId,
            round.price,
            round.targetAmount,
            round.amountRaised,
            round.endTime,
            round.startTime,
            round.isActive,
            timeRemaining
        );
    }

    function getRound(
        uint256 _roundId
    )
        external
        view
        returns (
            uint256 roundId,
            uint256 price,
            uint256 targetAmount,
            uint256 amountRaised,
            uint256 roundEndTime,
            uint256 roundStartTime,
            bool isActive
        )
    {
        require(_roundId < totalRounds, "Invalid round");
        Round storage round = rounds[_roundId];

        return (
            round.roundId,
            round.price,
            round.targetAmount,
            round.amountRaised,
            round.endTime,
            round.startTime,
            round.isActive
        );
    }

    function getRoundTimeRemaining(
        uint256 _roundId
    ) external view returns (uint256) {
        require(_roundId < totalRounds, "Invalid round");
        Round storage round = rounds[_roundId];

        if (!round.isActive || block.timestamp >= round.endTime) {
            return 0;
        }

        return round.endTime - block.timestamp;
    }

    // Purchase Functions
    function purchaseTokensWithETH(
        uint256 _tokenAmount
    )
        external
        payable
        nonReentrant
        whenNotPaused
        onlyDuringSale
        checkRequirements(msg.sender)
    {
        require(!isTierRequired, "Tier purchase required");
        require(_tokenAmount > 0, "Invalid amount");

        uint256 ethAmount = calculateETHAmountWithoutTier(_tokenAmount);
        require(msg.value >= ethAmount, "Insufficient ETH sent");

        _processSimplePurchase(_tokenAmount, ethAmount, "ETH");

        // Transfer ETH to treasury
        (bool success, ) = treasury.call{value: ethAmount}("");
        require(success, "ETH transfer failed");

        // Refund excess ETH
        if (msg.value > ethAmount) {
            (bool refundSuccess, ) = msg.sender.call{
                value: msg.value - ethAmount
            }("");
            require(refundSuccess, "ETH refund failed");
        }
    }

    function calculateTokensForETH(
        uint256 _ethAmount
    ) public view returns (uint256) {
        uint256 ethPrice = getETHPriceInUSD();
        require(ethPrice > 0, "Invalid ETH price");

        // ETH has 18 decimals, price has 8 decimals
        uint256 usdValue = _ethAmount.mul(ethPrice).div(1e18);

        // usdValue is now in 8 decimals (same as defaultTokenPrice)
        // Calculate tokens (result will be in 18 decimals)
        return usdValue.mul(1e18).div(defaultTokenPrice);
    }

    function calculateTokensForUSDT(
        uint256 _usdtAmount
    ) public view returns (uint256) {
        // USDT has 6 decimals, need to convert to 8 decimals to match token price
        uint256 usdtValue = _usdtAmount.mul(100); // Multiply by 100 to convert from 6 to 8 decimals
        return usdtValue.mul(1e18).div(defaultTokenPrice);
    }

    function purchaseTokensWithETHValue()
        external
        payable
        nonReentrant
        whenNotPaused
    {
        require(msg.value > 0, "Must send ETH");

        uint256 tokenAmount = calculateTokensForETH(msg.value);
        require(tokenAmount > 0, "Invalid token amount");
        require(
            saleToken.balanceOf(address(this)) >= tokenAmount,
            "Insufficient token balance"
        );

        _processSimplePurchase(tokenAmount, msg.value, "ETH");

        // Transfer ETH to treasury
        (bool success, ) = treasury.call{value: msg.value}("");
        require(success, "ETH transfer failed");
    }

    function purchaseTokensWithUSDTValue(
        uint256 _usdtAmount
    ) external nonReentrant whenNotPaused {
        require(_usdtAmount > 0, "Must send USDT");

        uint256 tokenAmount = calculateTokensForUSDT(_usdtAmount);
        require(tokenAmount > 0, "Invalid token amount");
        require(
            saleToken.balanceOf(address(this)) >= tokenAmount,
            "Insufficient token balance"
        );

        // Check USDT balance and allowance
        require(
            usdtToken.balanceOf(msg.sender) >= _usdtAmount,
            "Insufficient USDT balance"
        );
        require(
            usdtToken.allowance(msg.sender, address(this)) >= _usdtAmount,
            "Insufficient allowance"
        );

        // Transfer USDT before minting tokens to prevent reentrancy
        usdtToken.safeTransferFrom(msg.sender, treasury, _usdtAmount);

        _processSimplePurchase(tokenAmount, _usdtAmount, "USDT");
    }

    function purchaseTokensWithUSDT(
        uint256 _tokenAmount
    )
        external
        nonReentrant
        whenNotPaused
        onlyDuringSale
        checkRequirements(msg.sender)
    {
        require(!isTierRequired, "Tier purchase required");
        require(_tokenAmount > 0, "Invalid amount");

        uint256 usdtAmount = calculateUSDTAmountWithoutTier(_tokenAmount);
        usdtToken.safeTransferFrom(msg.sender, treasury, usdtAmount);

        _processSimplePurchase(_tokenAmount, usdtAmount, "USDT");
    }

    function purchaseWithETH(
        uint256 _tierId,
        uint256 _tokenAmount
    )
        external
        payable
        nonReentrant
        whenNotPaused
        onlyDuringSale
        checkRequirements(msg.sender)
    {
        require(isTierRequired, "Tier system disabled");

        Tier storage tier = tiers[_tierId];
        _validateTierPurchase(tier, _tokenAmount);

        uint256 ethAmount = calculateETHAmount(_tokenAmount, tier.price);
        require(msg.value >= ethAmount, "Insufficient ETH sent");

        _processTierPurchase(_tierId, _tokenAmount, ethAmount, "ETH");

        // Transfer ETH to treasury
        (bool success, ) = treasury.call{value: ethAmount}("");
        require(success, "ETH transfer failed");

        // Refund excess ETH
        if (msg.value > ethAmount) {
            (bool refundSuccess, ) = msg.sender.call{
                value: msg.value - ethAmount
            }("");
            require(refundSuccess, "ETH refund failed");
        }
    }

    function purchaseWithUSDT(
        uint256 _tierId,
        uint256 _tokenAmount
    )
        external
        nonReentrant
        whenNotPaused
        onlyDuringSale
        checkRequirements(msg.sender)
    {
        require(isTierRequired, "Tier system disabled");

        Tier storage tier = tiers[_tierId];
        _validateTierPurchase(tier, _tokenAmount);

        uint256 usdtAmount = calculateUSDTAmount(_tokenAmount, tier.price);
        usdtToken.safeTransferFrom(msg.sender, treasury, usdtAmount);

        _processTierPurchase(_tierId, _tokenAmount, usdtAmount, "USDT");
    }

    // Processing Functions
    function _processSimplePurchase(
        uint256 _tokenAmount,
        uint256 _paymentAmount,
        string memory _currency
    ) internal {
        UserInfo storage user = users[msg.sender];
        Round storage round = rounds[currentRound];

        require(round.isActive, "No active round");
        require(block.timestamp <= round.endTime, "Round ended");

        if (maxTokensPerUser > 0) {
            require(
                user.totalPurchased + _tokenAmount <= maxTokensPerUser,
                "Exceeds max tokens per user"
            );
        }
        if (userCaps[msg.sender] > 0) {
            require(
                user.totalPurchased + _tokenAmount <= userCaps[msg.sender],
                "Exceeds user cap"
            );
        }
        if (minPurchaseInterval > 0) {
            require(
                block.timestamp >= user.lastPurchaseTime + minPurchaseInterval,
                "Purchase too frequent"
            );
        }

        uint256 usdValue = keccak256(bytes(_currency)) ==
            keccak256(bytes("ETH"))
            ? convertETHtoUSD(_paymentAmount)
            : _paymentAmount;

        round.amountRaised += usdValue;

        if (round.amountRaised >= round.targetAmount) {
            emit RoundTargetReached(currentRound, round.amountRaised);
        }

        user.totalPurchased += _tokenAmount;
        user.lastPurchaseTime = block.timestamp;
        user.unclaimedTokens += _tokenAmount;

        totalTokensSold += _tokenAmount;
        totalRaised += usdValue;

        saleToken.approve(address(escrow), _tokenAmount);
        escrow.depositPublicSale(msg.sender, _tokenAmount);

        emit TokensPurchased(
            msg.sender,
            0,
            _tokenAmount,
            _paymentAmount,
            _currency,
            block.timestamp
        );
    }

    function _processTierPurchase(
        uint256 _tierId,
        uint256 _tokenAmount,
        uint256 _paymentAmount,
        string memory _currency
    ) internal {
        Tier storage tier = tiers[_tierId];
        UserInfo storage user = users[msg.sender];
        Round storage round = rounds[currentRound];

        require(round.isActive, "No active round");
        require(block.timestamp <= round.endTime, "Round ended");

        tier.soldTokens += _tokenAmount;
        totalTokensSold += _tokenAmount;

        user.totalPurchased += _tokenAmount;
        user.tiersPurchased.push(_tierId);
        user.lastPurchaseTime = block.timestamp;

        // Calculate USD value and update round amounts
        uint256 usdValue = keccak256(bytes(_currency)) ==
            keccak256(bytes("ETH"))
            ? convertETHtoUSD(_paymentAmount)
            : _paymentAmount;

        round.amountRaised += usdValue;

        // Emit event if target reached
        if (round.amountRaised >= round.targetAmount) {
            emit RoundTargetReached(currentRound, round.amountRaised);
        }

        totalRaised += usdValue;
        user.totalInvested += usdValue;

        // Continue with existing vesting logic
        if (!allowDirectWithdraw) {
            escrow.deposit(
                msg.sender,
                _tokenAmount,
                tier.vestingPeriod,
                _tierId
            );
        } else {
            user.unclaimedTokens += _tokenAmount;
        }

        emit TokensPurchased(
            msg.sender,
            _tierId,
            _tokenAmount,
            _paymentAmount,
            _currency,
            block.timestamp
        );
    }

    function setMinPurchaseInterval(
        uint _minPurchaseInterval
    ) external onlyAdminOrOwner returns (uint minPurchaseIntervalInHours) {
        minPurchaseInterval = _minPurchaseInterval * 1 hours;
        return minPurchaseInterval;
    }

    // Validation Functions
    function _validateTierPurchase(
        Tier storage tier,
        uint256 _tokenAmount
    ) internal view {
        require(tier.isActive, "Tier not active");
        require(
            block.timestamp >= tier.startTime &&
                block.timestamp <= tier.endTime,
            "Tier not active"
        );
        require(_tokenAmount >= tier.minPurchase, "Below min purchase");
        require(_tokenAmount <= tier.maxPurchase, "Exceeds max purchase");
        require(
            tier.soldTokens + _tokenAmount <= tier.maxTokens,
            "Exceeds tier capacity"
        );
    }

    // Withdrawal Functions
    function withdrawTokens() external nonReentrant whenNotPaused {
        require(allowDirectWithdraw, "Withdrawals not allowed");
        UserInfo storage user = users[msg.sender];
        require(user.unclaimedTokens > 0, "No tokens to withdraw");

        uint256 amount = user.unclaimedTokens;
        user.unclaimedTokens = 0;

        escrow.withdrawPublicSale(msg.sender);
        emit TokensWithdrawn(msg.sender, amount);
    }

    // Admin Functions
    function addTier(
        uint256 _price,
        uint256 _minPurchase,
        uint256 _maxPurchase,
        uint256 _maxTokens,
        uint256 _vestingPeriod,
        uint256 _startTime,
        uint256 _endTime
    ) external onlyOwner {
        require(_price > 0, "Invalid price");
        require(_maxPurchase >= _minPurchase, "Invalid purchase limits");
        require(_maxTokens > 0, "Invalid max tokens");
        require(_startTime >= block.timestamp, "Invalid start time");
        require(_endTime > _startTime, "Invalid end time");

        uint256 tierId = totalTiers++;
        tiers[tierId] = Tier({
            price: _price,
            minPurchase: _minPurchase,
            maxPurchase: _maxPurchase,
            maxTokens: _maxTokens,
            soldTokens: 0,
            vestingPeriod: _vestingPeriod,
            startTime: _startTime,
            endTime: _endTime,
            isActive: true
        });

        emit TierAdded(tierId, _price, _maxTokens, _startTime, _endTime);
    }

    function setRequirementControls(
        bool _whitelistRequired,
        bool _kycRequired,
        bool _tierRequired
    ) external onlyOwner {
        isWhitelistRequired = _whitelistRequired;
        isKYCRequired = _kycRequired;
        isTierRequired = _tierRequired;

        emit RequirementControlsUpdated(
            _whitelistRequired,
            _kycRequired,
            _tierRequired
        );
    }

    function setDirectWithdrawAllowed(bool _allowed) external onlyAdminOrOwner {
        allowDirectWithdraw = _allowed;
        escrow.setPublicSaleWithdrawalsEnabled(_allowed);
        emit WithdrawControlUpdated(_allowed);
    }

    function updateKYCStatus(
        address[] calldata _users,
        bool[] calldata _statuses
    ) external onlyAdminOrOwner {
        require(_users.length == _statuses.length, "Array length mismatch");
        for (uint256 i = 0; i < _users.length; i++) {
            users[_users[i]].hasKYC = _statuses[i];
            emit KYCStatusUpdated(_users[i], _statuses[i]);
        }
    }

    function updateWhitelist(
        address[] calldata _users,
        bool[] calldata _statuses
    ) external onlyAdminOrOwner {
        require(_users.length == _statuses.length, "Array length mismatch");
        for (uint256 i = 0; i < _users.length; i++) {
            whitelist[_users[i]] = _statuses[i];
            emit WhitelistUpdated(_users[i], _statuses[i]);
        }
    }

    function setDefaultTokenPrice(uint256 _price) external onlyOwner {
        require(_price > 0, "Invalid price");
        uint256 oldPrice = defaultTokenPrice;
        defaultTokenPrice = _price;
        emit DefaultPriceUpdated(oldPrice, _price);
    }

    function setUserCap(address _user, uint256 _cap) external onlyAdminOrOwner {
        userCaps[_user] = _cap;
        emit UserCapUpdated(_user, _cap);
    }

    function updateAdmin(address _newAdmin) external onlyOwner {
        require(_newAdmin != address(0), "Invalid admin address");
        address oldAdmin = admin;
        admin = _newAdmin;
        emit AdminUpdated(oldAdmin, _newAdmin);
    }

    function updateTreasury(address _newTreasury) external onlyOwner {
        require(_newTreasury != address(0), "Invalid treasury address");
        address oldTreasury = treasury;
        treasury = _newTreasury;
        emit TreasuryUpdated(oldTreasury, _newTreasury);
    }

    // Price Calculation Functions
    function getETHPriceInUSD() public view returns (uint256) {
        (uint256 price, ) = priceOracle.getLatestPrice();
        return price;
    }

    function convertETHtoUSD(uint256 _ethAmount) public view returns (uint256) {
        uint256 ethPrice = getETHPriceInUSD();
        return (_ethAmount * ethPrice) / 1e18;
    }

    function calculateETHAmountWithoutTier(
        uint256 _tokenAmount
    ) public view returns (uint256) {
        uint256 ethPrice = getETHPriceInUSD();
        require(ethPrice > 0, "Invalid ETH price");
        uint256 usdValue = (_tokenAmount * defaultTokenPrice) /
            (10 ** PRICE_DECIMALS);
        return (usdValue * 1e18) / ethPrice;
    }

    function calculateUSDTAmountWithoutTier(
        uint256 _tokenAmount
    ) public view returns (uint256) {
        return (_tokenAmount * defaultTokenPrice) / (10 ** PRICE_DECIMALS);
    }

    function calculateETHAmount(
        uint256 _tokenAmount,
        uint256 _price
    ) public view returns (uint256) {
        uint256 ethPrice = getETHPriceInUSD();
        uint256 usdtAmount = (_tokenAmount * _price) / (10 ** PRICE_DECIMALS);
        return (usdtAmount * 1e18) / ethPrice;
    }

    function calculateUSDTAmount(
        uint256 _tokenAmount,
        uint256 _price
    ) public pure returns (uint256) {
        return (_tokenAmount * _price) / (10 ** PRICE_DECIMALS);
    }

    // View Functions
    function getTier(uint256 _tierId) external view returns (Tier memory) {
        return tiers[_tierId];
    }

    function getUserInfo(
        address _user
    )
        external
        view
        returns (
            uint256 totalPurchased,
            uint256 totalInvested,
            uint256[] memory tiersPurchased,
            bool hasKYC,
            uint256 lastPurchaseTime,
            uint256 unclaimedTokens
        )
    {
        UserInfo storage user = users[_user];
        return (
            user.totalPurchased,
            user.totalInvested,
            user.tiersPurchased,
            user.hasKYC,
            user.lastPurchaseTime,
            user.unclaimedTokens
        );
    }

    // Emergency Functions
    function emergencyWithdraw(address _token) external onlyOwner {
        require(_token != address(saleToken), "Cannot withdraw sale token");
        uint256 balance = IERC20Upgradeable(_token).balanceOf(address(this));
        require(balance > 0, "No tokens to withdraw");
        IERC20Upgradeable(_token).safeTransfer(treasury, balance);
    }

    function pause() external onlyOwner {
        _pause();
    }

    function unpause() external onlyOwner {
        _unpause();
    }

    receive() external payable {
        revert("Direct ETH transfers not allowed");
    }
}
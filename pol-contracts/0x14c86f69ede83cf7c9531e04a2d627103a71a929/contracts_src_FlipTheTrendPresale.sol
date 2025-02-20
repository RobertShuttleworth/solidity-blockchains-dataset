// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "./openzeppelin_contracts-upgradeable_token_ERC20_IERC20Upgradeable.sol";
import "./openzeppelin_contracts-upgradeable_access_OwnableUpgradeable.sol";
import "./openzeppelin_contracts-upgradeable_security_ReentrancyGuardUpgradeable.sol";
import "./openzeppelin_contracts-upgradeable_token_ERC20_utils_SafeERC20Upgradeable.sol";
import "./openzeppelin_contracts-upgradeable_proxy_utils_Initializable.sol";
import "./openzeppelin_contracts-upgradeable_security_PausableUpgradeable.sol";
import "./openzeppelin_contracts-upgradeable_proxy_utils_UUPSUpgradeable.sol";

interface IAlgebraPositionManager {
    struct MintParams {
        address token0;
        address token1;
        int24 tickLower;
        int24 tickUpper;
        uint256 amount0Desired;
        uint256 amount1Desired;
        uint256 amount0Min;
        uint256 amount1Min;
        address recipient;
        uint256 deadline;
    }

    function mint(MintParams calldata params)
        external
        payable
        returns (
            uint256 tokenId,
            uint128 liquidity,
            uint256 amount0,
            uint256 amount1
        );
}

error InsufficientTokenBalance(uint256 required, uint256 current);

contract FlipTheTrendPresale is 
    Initializable, 
    OwnableUpgradeable, 
    ReentrancyGuardUpgradeable,
    PausableUpgradeable,
    UUPSUpgradeable 
{
    using SafeERC20Upgradeable for IERC20Upgradeable;

    // Constants
    uint256 public constant TOKENS_FOR_PRESALE = 500_000_000 * 1e18; // 500M FLIP tokens
    uint256 public constant MIN_CONTRIBUTION = 10 * 1e18;  // 10 POL minimum
    uint256 public constant MAX_CONTRIBUTION = 10_000 * 1e18; // 10,000 POL maximum
    uint256 public constant PRESALE_PRICE = 2380 * 1e18; // 2,380 FLIP per POL
    uint256 public constant LIQUIDITY_TIMEOUT = 30 minutes; // Timeout for liquidity addition
    uint256 public constant SLIPPAGE_DENOMINATOR = 10000; // 100% = 10000
    uint256 public constant MIN_LIQUIDITY_THRESHOLD = 1000 * 1e18; // Minimum 1000 POL worth of liquidity
    uint256 public constant TIMELOCK_DURATION = 24 hours; // 24 hour timelock for critical functions

    // State variables
    IERC20Upgradeable public flipToken;
    IERC20Upgradeable public wmatic;
    IAlgebraPositionManager public positionManager;
    
    uint256 public totalRaised;
    uint256 public hardCap;
    bool public presaleStarted;
    bool public presaleFinalized;
    uint256 public slippageTolerance; // In basis points (e.g., 100 = 1%)
    uint256 public totalParticipants;
    uint256 public totalTokensSold;
    uint256 public startTime;
    
    // Timelock variables
    mapping(bytes32 => uint256) public timelockExpiries;
    mapping(bytes32 => bool) public timelockExecuted;
    
    mapping(address => uint256) public contributions;
    mapping(address => bool) public hasContributed;

    // Events
    event TokensPurchased(address indexed buyer, uint256 polAmount, uint256 tokenAmount);
    event PresaleFinalized(uint256 totalRaised, uint256 tokensForLiquidity);
    event LiquidityAdded(uint256 flipAmount, uint256 polAmount, uint256 tokenId);
    event SlippageToleranceUpdated(uint256 newTolerance);
    event PresaleStarted(uint256 timestamp, uint256 hardCap);
    event PresaleProgress(uint256 totalRaised, uint256 participantCount, uint256 percentageComplete);
    event TimelockScheduled(bytes32 indexed txHash, uint256 executionTime);
    event TimelockExecuted(bytes32 indexed txHash);
    event EmergencyPaused(address indexed by);
    event EmergencyUnpaused(address indexed by);
    event AdminActionPerformed(string indexed action, address indexed by, uint256 timestamp);
    event TokensReceived(uint256 amount, uint256 totalBalance);
    event TokenBalanceValidated(uint256 currentBalance, uint256 requiredBalance, bool sufficient);

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    function initialize(
        address _flipToken,
        address _wmatic,
        address _positionManager
    ) public initializer {
        __Ownable_init();
        __ReentrancyGuard_init();
        __Pausable_init();

        require(_flipToken != address(0), "Invalid FLIP token address");
        require(_wmatic != address(0), "Invalid POL token address");
        require(_positionManager != address(0), "Invalid position manager address");

        flipToken = IERC20Upgradeable(_flipToken);
        wmatic = IERC20Upgradeable(_wmatic);
        positionManager = IAlgebraPositionManager(_positionManager);
        
        hardCap = 210_000 * 1e18; // 210,000 POL target
        slippageTolerance = 100; // Default 1% slippage tolerance
    }

    // Function to check current token balance
    function checkTokenBalance() public view returns (uint256 balance, bool hasRequiredTokens) {
        uint256 currentBalance = flipToken.balanceOf(address(this));
        return (currentBalance, currentBalance >= TOKENS_FOR_PRESALE);
    }

    // Function to validate token balance with events
    function validateTokenBalance() public returns (uint256 balance, bool hasRequiredTokens) {
        (balance, hasRequiredTokens) = checkTokenBalance();
        emit TokenBalanceValidated(balance, TOKENS_FOR_PRESALE, hasRequiredTokens);
    }

    // Timelock functions
    function scheduleAction(bytes32 actionHash) internal {
        require(timelockExpiries[actionHash] == 0, "Action already scheduled");
        timelockExpiries[actionHash] = block.timestamp + TIMELOCK_DURATION;
        emit TimelockScheduled(actionHash, timelockExpiries[actionHash]);
    }

    function executeAction(bytes32 actionHash) internal {
        require(timelockExpiries[actionHash] > 0, "Action not scheduled");
        require(block.timestamp >= timelockExpiries[actionHash], "Timelock not expired");
        require(!timelockExecuted[actionHash], "Action already executed");
        
        timelockExecuted[actionHash] = true;
        emit TimelockExecuted(actionHash);
    }

    // Emergency functions
    function emergencyPause() external onlyOwner {
        _pause();
        emit EmergencyPaused(msg.sender);
    }

    function emergencyUnpause() external onlyOwner {
        _unpause();
        emit EmergencyUnpaused(msg.sender);
    }

    // Owner functions
    function startPresale() external onlyOwner whenNotPaused {
        require(!presaleStarted, "Presale already started");
        
        // Verify token balance
        (uint256 balance, bool hasTokens) = validateTokenBalance();
        if (!hasTokens) {
            revert InsufficientTokenBalance({
                required: TOKENS_FOR_PRESALE,
                current: balance
            });
        }

        // Additional safety check for exact amount
        require(balance == TOKENS_FOR_PRESALE, "Incorrect token amount");

        presaleStarted = true;
        startTime = block.timestamp;
        
        emit PresaleStarted(block.timestamp, hardCap);
        emit AdminActionPerformed("startPresale", msg.sender, block.timestamp);
    }

    function updatePositionManager(address _newPositionManager) external onlyOwner whenNotPaused {
        require(_newPositionManager != address(0), "Invalid position manager address");
        positionManager = IAlgebraPositionManager(_newPositionManager);
        emit AdminActionPerformed("updatePositionManager", msg.sender, block.timestamp);
    }

    function setSlippageTolerance(uint256 _newTolerance) external onlyOwner {
        require(_newTolerance <= 1000, "Slippage tolerance too high"); // Max 10%
        slippageTolerance = _newTolerance;
        emit SlippageToleranceUpdated(_newTolerance);
        emit AdminActionPerformed("setSlippageTolerance", msg.sender, block.timestamp);
    }

    function finalizePresale() public whenNotPaused {
        require(presaleStarted, "Presale not started");
        require(totalRaised >= hardCap, "Cap not reached");
        require(!presaleFinalized, "Presale already finalized");
        require(totalRaised >= MIN_LIQUIDITY_THRESHOLD, "Insufficient liquidity");
        require(address(this).balance >= totalRaised, "Invalid balance state");

        presaleFinalized = true;

        // Add all raised MATIC and remaining FLIP tokens to liquidity
        uint256 maticBalance = address(this).balance;
        uint256 remainingFlip = flipToken.balanceOf(address(this));
        
        require(maticBalance > 0, "No MATIC for liquidity");
        require(remainingFlip > 0, "No FLIP for liquidity");

        // Calculate minimum amounts based on slippage tolerance
        uint256 minFlip = remainingFlip * (SLIPPAGE_DENOMINATOR - slippageTolerance) / SLIPPAGE_DENOMINATOR;
        uint256 minMatic = maticBalance * (SLIPPAGE_DENOMINATOR - slippageTolerance) / SLIPPAGE_DENOMINATOR;
        
        require(minFlip > 0, "Invalid min FLIP amount");
        require(minMatic > 0, "Invalid min MATIC amount");

        // Approve tokens for position manager
        flipToken.approve(address(positionManager), 0);
        flipToken.approve(address(positionManager), remainingFlip);
        
        // Add liquidity to Algebra (QuickSwap V3)
        IAlgebraPositionManager.MintParams memory params = IAlgebraPositionManager.MintParams({
            token0: address(flipToken),
            token1: address(wmatic),
            tickLower: -887220,  // Price range from -10x to +10x
            tickUpper: 887220,
            amount0Desired: remainingFlip,
            amount1Desired: maticBalance,
            amount0Min: minFlip,
            amount1Min: minMatic,
            recipient: owner(),
            deadline: block.timestamp + LIQUIDITY_TIMEOUT
        });

        (uint256 tokenId, , uint256 amount0, uint256 amount1) = positionManager.mint{value: maticBalance}(params);
        
        require(tokenId != 0, "Invalid position ID");
        require(amount0 > 0 && amount1 > 0, "Invalid liquidity amounts");

        emit PresaleFinalized(totalRaised, remainingFlip);
        emit LiquidityAdded(amount0, amount1, tokenId);
    }

    function setHardCap(uint256 _newHardCap) external onlyOwner whenNotPaused {
        bytes32 actionHash = keccak256(abi.encodePacked("setHardCap", _newHardCap));
        
        if (timelockExpiries[actionHash] == 0) {
            scheduleAction(actionHash);
            return;
        }
        
        require(block.timestamp >= timelockExpiries[actionHash], "Timelock not expired");
        require(!timelockExecuted[actionHash], "Action already executed");
        
        timelockExecuted[actionHash] = true;
        require(_newHardCap > totalRaised, "New hard cap too low");
        hardCap = _newHardCap;
        
        emit TimelockExecuted(actionHash);
        emit AdminActionPerformed("setHardCap", msg.sender, block.timestamp);
    }

    function withdrawUnsoldTokens() external onlyOwner whenNotPaused {
        require(presaleFinalized, "Presale not finalized");
        uint256 remainingTokens = flipToken.balanceOf(address(this));
        if (remainingTokens > 0) {
            flipToken.safeTransfer(owner(), remainingTokens);
            emit AdminActionPerformed("withdrawUnsoldTokens", msg.sender, block.timestamp);
        }
    }

    // Public functions
    function buyTokens() external payable nonReentrant whenNotPaused {
        require(presaleStarted, "Presale not started");
        require(!presaleFinalized, "Presale finalized");
        require(msg.value >= MIN_CONTRIBUTION, "Below minimum contribution");
        require(msg.value <= MAX_CONTRIBUTION, "Above maximum contribution");
        require(msg.sender != address(0), "Invalid sender address");
        require(msg.value > 0, "Zero contribution");
        
        uint256 newContribution = contributions[msg.sender] + msg.value;
        require(newContribution <= MAX_CONTRIBUTION, "Would exceed max contribution");
        
        uint256 newTotalRaised = totalRaised + msg.value;
        require(newTotalRaised <= hardCap, "Would exceed hard cap");

        uint256 tokenAmount = msg.value * PRESALE_PRICE / 1e18;
        require(flipToken.balanceOf(address(this)) >= tokenAmount, "Insufficient tokens");
        require(tokenAmount > 0, "Zero tokens");

        // Save state before external calls
        totalRaised = newTotalRaised;
        contributions[msg.sender] = newContribution;
        totalTokensSold += tokenAmount;
        
        if (!hasContributed[msg.sender]) {
            hasContributed[msg.sender] = true;
            totalParticipants++;
        }
        
        // External calls after state changes (CEI pattern)
        flipToken.safeTransfer(msg.sender, tokenAmount);
        
        emit TokensPurchased(msg.sender, msg.value, tokenAmount);
        emit PresaleProgress(totalRaised, totalParticipants, (totalRaised * 10000) / hardCap);

        // Auto-finalize when cap is hit
        if (totalRaised == hardCap) {
            finalizePresale();
        }
    }

    // View functions
    function getContribution(address contributor) external view returns (uint256) {
        require(contributor != address(0), "Invalid address");
        return contributions[contributor];
    }

    function presaleStatus() external view returns (
        uint256 _totalRaised,
        uint256 _hardCap,
        bool _started,
        bool _finalized
    ) {
        return (totalRaised, hardCap, presaleStarted, presaleFinalized);
    }

    function getDetailedPresaleInfo() external view returns (
        uint256 _totalRaised,
        uint256 _hardCap,
        uint256 _totalParticipants,
        uint256 _totalTokensSold,
        uint256 _remainingTokens,
        uint256 _percentageComplete,
        uint256 _presaleStartTime,
        uint256 _elapsedTime,
        bool _isActive,
        bool _isFinalized,
        bool _isPaused
    ) {
        uint256 remainingTokens = flipToken.balanceOf(address(this)) - totalTokensSold;
        uint256 percentageComplete = (totalRaised * 10000) / hardCap;
        uint256 elapsedTime = presaleStarted ? block.timestamp - startTime : 0;
        
        return (
            totalRaised,
            hardCap,
            totalParticipants,
            totalTokensSold,
            remainingTokens,
            percentageComplete,
            startTime,
            elapsedTime,
            presaleStarted && !presaleFinalized,
            presaleFinalized,
            paused()
        );
    }

    function getParticipantInfo(address participant) external view returns (
        uint256 contribution,
        uint256 tokensBought,
        bool hasParticipated
    ) {
        require(participant != address(0), "Invalid address");
        return (
            contributions[participant],
            contributions[participant] * PRESALE_PRICE / 1e18,
            hasContributed[participant]
        );
    }

    // Override receive function to track token transfers
    receive() external payable {
        revert("Use buyTokens() to participate in the presale");
    }

    // Add a hook to track token transfers
    function _beforeTokenTransfer(address from, address to, uint256 amount) internal virtual {
        if (from != address(0) && to == address(this)) {
            uint256 newBalance = flipToken.balanceOf(address(this)) + amount;
            emit TokensReceived(amount, newBalance);
            
            // Validate if this brings us to the required amount
            if (newBalance >= TOKENS_FOR_PRESALE) {
                emit TokenBalanceValidated(newBalance, TOKENS_FOR_PRESALE, true);
            }
        }
    }

    // Add the _authorizeUpgrade function
    function _authorizeUpgrade(address newImplementation) internal override onlyOwner {
        // Add any additional upgrade authorization logic here
    }
} 
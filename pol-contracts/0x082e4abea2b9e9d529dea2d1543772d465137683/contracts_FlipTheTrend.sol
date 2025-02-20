// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "./openzeppelin_contracts-upgradeable_token_ERC20_ERC20Upgradeable.sol";
import "./openzeppelin_contracts-upgradeable_security_PausableUpgradeable.sol";
import "./openzeppelin_contracts-upgradeable_access_AccessControlUpgradeable.sol";
import "./openzeppelin_contracts-upgradeable_proxy_utils_Initializable.sol";
import "./openzeppelin_contracts-upgradeable_proxy_utils_UUPSUpgradeable.sol";
import "./openzeppelin_contracts-upgradeable_security_ReentrancyGuardUpgradeable.sol";
import "./contracts_interfaces_IAlgebraPositionManager.sol";

contract FlipTheTrend is 
    Initializable,
    ERC20Upgradeable,
    PausableUpgradeable,
    AccessControlUpgradeable,
    UUPSUpgradeable,
    ReentrancyGuardUpgradeable 
{
    // Packed storage variables to save gas
    struct HealthParameters {
        uint96 minLiquidity;
        uint96 minValue0;
        uint96 minValue1;
        uint16 maxTickDeviation;
        uint32 maxInactiveTime;
        uint8 emergencyThreshold;
    }

    struct Position {
        bool isActive;
        uint96 liquidity;
        uint96 value0;
        uint96 value1;
        int24 tickLower;
        int24 tickUpper;
        uint32 lastUpdateTime;
        uint8 healthScore;
        uint16 fee;
        address owner;
    }

    // Constants
    uint256 private constant MAX_POSITIONS = 1000;
    uint256 private constant TOTAL_SUPPLY = 1_000_000_000 * 10**18; // 1 billion tokens
    uint256 private constant INITIAL_SUPPLY = TOTAL_SUPPLY / 2; // 50% of total supply (500 million tokens)
    bytes32 public constant ADMIN_ROLE = keccak256("ADMIN_ROLE");
    bytes32 public constant PAUSER_ROLE = keccak256("PAUSER_ROLE");
    bytes32 public constant MINTER_ROLE = keccak256("MINTER_ROLE");

    // State variables
    bool private remainingSupplyMinted;
    IAlgebraPositionManager public positionManager;
    HealthParameters private healthParams;
    mapping(uint256 => Position) private positions;
    uint256 private currentPage;
    uint256 private totalPositions;

    // Events with indexed parameters for efficient filtering
    event PositionCreated(uint256 indexed positionId, address indexed owner);
    event PositionClosed(uint256 indexed positionId);
    event PositionManagerUpdated(address indexed newManager);
    event HealthParametersUpdated();
    event PositionsProcessed(uint256 indexed count, uint256 indexed page);
    event EmergencyThresholdBreached(uint256 indexed positionId, uint8 newScore);
    event HealthScoreUpdated(uint256 indexed positionId, uint8 oldScore, uint8 newScore);
    event LiquidityChanged(uint256 indexed positionId, uint96 oldLiquidity, uint96 newLiquidity);
    event TokensCollected(uint256 indexed positionId, uint256 amount0, uint256 amount1);
    event InitialSupplyMinted(address indexed to, uint256 amount);
    event PositionTransferred(uint256 indexed positionId, address indexed from, address indexed to);
    event RemainingSupplyMinted(address indexed to, uint256 amount);

    // Custom errors to save gas
    error MaxPositionsReached();
    error InvalidPositionManager();
    error InvalidParameters();
    error PositionNotActive();
    error UnauthorizedAccess();
    error InvalidPositionId();
    error InsufficientLiquidity();
    error InvalidAmount();
    error DeadlineExpired();
    error SlippageExceeded();
    error InvalidHealthScore();
    error RemainingSupplyAlreadyMinted();

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    function initialize(
        string memory name_,
        string memory symbol_,
        address positionManager_,
        uint96 minLiquidity_,
        uint96 minValue0_,
        uint96 minValue1_,
        uint16 maxTickDeviation_,
        uint32 maxInactiveTime_,
        uint8 emergencyThreshold_
    ) public initializer {
        __ERC20_init(name_, symbol_);
        __Pausable_init();
        __AccessControl_init();
        __UUPSUpgradeable_init();
        __ReentrancyGuard_init();

        // Default to "FLIP" if no symbol is provided
        if (bytes(symbol_).length == 0) {
            symbol_ = "FLIP";
        }

        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _grantRole(ADMIN_ROLE, msg.sender);
        _grantRole(PAUSER_ROLE, msg.sender);
        _grantRole(MINTER_ROLE, msg.sender);

        if (positionManager_ == address(0)) revert InvalidPositionManager();
        positionManager = IAlgebraPositionManager(positionManager_);

        // Initial supply minting (50%)
        _mint(msg.sender, INITIAL_SUPPLY);
        emit InitialSupplyMinted(msg.sender, INITIAL_SUPPLY);

        // Set health parameters
        healthParams = HealthParameters({
            minLiquidity: minLiquidity_,
            minValue0: minValue0_,
            minValue1: minValue1_,
            maxTickDeviation: maxTickDeviation_,
            maxInactiveTime: maxInactiveTime_,
            emergencyThreshold: emergencyThreshold_
        });
    }

    function createPosition(
        address token0,
        address token1,
        uint16 fee,
        int24 tickLower,
        int24 tickUpper,
        uint96 amount0,
        uint96 amount1,
        uint96 minAmount0,
        uint96 minAmount1,
        uint256 deadline
    ) external nonReentrant whenNotPaused returns (uint256 positionId) {
        if (block.timestamp > deadline) revert DeadlineExpired();
        if (amount0 == 0 || amount1 == 0) revert InvalidAmount();
        if (totalPositions >= MAX_POSITIONS) revert MaxPositionsReached();

        unchecked {
            positionId = totalPositions++;
        }

        // Transfer tokens from user to this contract
        IERC20Upgradeable(token0).transferFrom(msg.sender, address(this), amount0);
        IERC20Upgradeable(token1).transferFrom(msg.sender, address(this), amount1);

        // Create position using the position manager
        IAlgebraPositionManager.MintParams memory params = IAlgebraPositionManager.MintParams({
            token0: token0,
            token1: token1,
            fee: fee,
            tickLower: tickLower,
            tickUpper: tickUpper,
            amount0Desired: amount0,
            amount1Desired: amount1,
            amount0Min: minAmount0,
            amount1Min: minAmount1,
            recipient: address(this),
            deadline: deadline
        });

        (uint256 pmTokenId, uint128 liquidity, uint256 amount0Created, uint256 amount1Created) = 
            positionManager.mint(params);

        if (amount0Created < minAmount0 || amount1Created < minAmount1) revert SlippageExceeded();

        // Initialize position data
        positions[positionId] = Position({
            isActive: true,
            liquidity: uint96(liquidity),
            value0: uint96(amount0Created),
            value1: uint96(amount1Created),
            tickLower: tickLower,
            tickUpper: tickUpper,
            lastUpdateTime: uint32(block.timestamp),
            healthScore: 100,
            fee: fee,
            owner: msg.sender
        });

        emit PositionCreated(positionId, msg.sender);
        emit LiquidityChanged(positionId, 0, uint96(liquidity));
    }

    function closePosition(uint256 positionId) external nonReentrant whenNotPaused {
        Position storage position = positions[positionId];
        if (!position.isActive) revert PositionNotActive();
        if (position.owner != msg.sender) revert UnauthorizedAccess();

        uint96 oldLiquidity = position.liquidity;
        position.isActive = false;
        position.liquidity = 0;

        // Decrease liquidity in the position manager
        IAlgebraPositionManager.DecreaseLiquidityParams memory params = IAlgebraPositionManager.DecreaseLiquidityParams({
            tokenId: positionId,
            liquidity: uint128(oldLiquidity),
            amount0Min: 0,
            amount1Min: 0,
            deadline: block.timestamp
        });

        positionManager.decreaseLiquidity(params);

        // Collect any remaining fees
        IAlgebraPositionManager.CollectParams memory collectParams = IAlgebraPositionManager.CollectParams({
            tokenId: positionId,
            recipient: msg.sender,
            amount0Max: type(uint128).max,
            amount1Max: type(uint128).max
        });

        (uint256 amount0, uint256 amount1) = positionManager.collect(collectParams);

        emit PositionClosed(positionId);
        emit LiquidityChanged(positionId, oldLiquidity, 0);
        emit TokensCollected(positionId, amount0, amount1);
    }

    function processPositions(uint256 batchSize) external whenNotPaused {
        if (batchSize == 0) revert InvalidAmount();
        
        uint256 processed;
        uint256 page = currentPage;
        uint256 total = totalPositions;

        for (uint256 i = 0; i < batchSize;) {
            uint256 posIndex = page * batchSize + i;
            if (posIndex >= total) break;

            Position storage position = positions[posIndex];
            if (position.isActive) {
                // Update health score based on time since last update
                uint32 timeSinceUpdate = uint32(block.timestamp) - position.lastUpdateTime;
                uint8 oldScore = position.healthScore;
                
                if (timeSinceUpdate > healthParams.maxInactiveTime) {
                    position.healthScore = 0;
                    emit HealthScoreUpdated(posIndex, oldScore, 0);
                } else {
                    // Calculate new health score based on parameters
                    uint8 newScore = _calculateHealthScore(
                        position.liquidity,
                        position.value0,
                        position.value1,
                        position.tickLower,
                        position.tickUpper,
                        timeSinceUpdate
                    );
                    position.healthScore = newScore;
                    emit HealthScoreUpdated(posIndex, oldScore, newScore);

                    // Check if emergency threshold is breached
                    if (newScore < healthParams.emergencyThreshold) {
                        _pause();
                        emit EmergencyThresholdBreached(posIndex, newScore);
                        break;
                    }
                }

                position.lastUpdateTime = uint32(block.timestamp);
                processed++;
            }

            unchecked { ++i; }
        }

        if (processed > 0) {
            unchecked {
                currentPage++;
            }
            emit PositionsProcessed(processed, page);
        }
    }

    function _calculateHealthScore(
        uint96 liquidity,
        uint96 value0,
        uint96 value1,
        int24 tickLower,
        int24 tickUpper,
        uint32 timeSinceUpdate
    ) internal view returns (uint8) {
        if (liquidity == 0) revert InsufficientLiquidity();
        if (value0 == 0 || value1 == 0) revert InvalidAmount();
        if (tickLower >= tickUpper) revert InvalidParameters();
        
        // Base score starts at 100
        uint256 score = 100;

        // Deduct points for low liquidity
        if (liquidity < healthParams.minLiquidity) {
            score = score * uint256(liquidity) / uint256(healthParams.minLiquidity);
        }

        // Deduct points for low token values
        if (value0 < healthParams.minValue0) {
            score = score * uint256(value0) / uint256(healthParams.minValue0);
        }
        if (value1 < healthParams.minValue1) {
            score = score * uint256(value1) / uint256(healthParams.minValue1);
        }

        // Deduct points for wide tick range
        uint256 tickRange = uint256(uint24(tickUpper - tickLower));
        if (tickRange > uint256(healthParams.maxTickDeviation)) {
            score = score * uint256(healthParams.maxTickDeviation) / tickRange;
        }

        // Deduct points for time since last update
        if (timeSinceUpdate > healthParams.maxInactiveTime / 2) {
            uint256 timeScore = uint256(healthParams.maxInactiveTime - timeSinceUpdate);
            score = score * timeScore / uint256(healthParams.maxInactiveTime);
        }

        uint8 finalScore = uint8(score > 100 ? 100 : score);
        if (finalScore == 0) revert InvalidHealthScore();
        return finalScore;
    }

    function getPositionInfo(uint256 positionId) external view returns (Position memory) {
        return positions[positionId];
    }

    function getHealthParameters() external view returns (HealthParameters memory) {
        return healthParams;
    }

    function getCurrentPage() external view returns (uint256) {
        return currentPage;
    }

    function updatePositionManager(address newManager) external onlyRole(ADMIN_ROLE) {
        if (newManager == address(0)) revert InvalidPositionManager();
        positionManager = IAlgebraPositionManager(newManager);
        emit PositionManagerUpdated(newManager);
    }

    function updateHealthParameters(
        uint96 minLiquidity_,
        uint96 minValue0_,
        uint96 minValue1_,
        uint16 maxTickDeviation_,
        uint32 maxInactiveTime_,
        uint8 emergencyThreshold_
    ) external onlyRole(ADMIN_ROLE) {
        healthParams = HealthParameters({
            minLiquidity: minLiquidity_,
            minValue0: minValue0_,
            minValue1: minValue1_,
            maxTickDeviation: maxTickDeviation_,
            maxInactiveTime: maxInactiveTime_,
            emergencyThreshold: emergencyThreshold_
        });
        emit HealthParametersUpdated();
    }

    function pause() external onlyRole(PAUSER_ROLE) {
        _pause();
    }

    function unpause() external onlyRole(PAUSER_ROLE) {
        _unpause();
    }

    function _authorizeUpgrade(address newImplementation) internal override onlyRole(DEFAULT_ADMIN_ROLE) {}

    // The following functions are overrides required by Solidity
    function supportsInterface(bytes4 interfaceId) public view virtual override(AccessControlUpgradeable) returns (bool) {
        return super.supportsInterface(interfaceId);
    }

    // Function to mint remaining 50% of supply
    function mintRemainingSupply(address to) external onlyRole(ADMIN_ROLE) {
        if (remainingSupplyMinted) revert RemainingSupplyAlreadyMinted();
        remainingSupplyMinted = true;
        _mint(to, INITIAL_SUPPLY); // Mint remaining 50%
        emit RemainingSupplyMinted(to, INITIAL_SUPPLY);
    }
}
// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import './openzeppelin_contracts-upgradeable_access_AccessControlUpgradeable.sol';
import './openzeppelin_contracts-upgradeable_utils_PausableUpgradeable.sol';
import './openzeppelin_contracts-upgradeable_utils_ReentrancyGuardUpgradeable.sol';
import './openzeppelin_contracts-upgradeable_proxy_utils_UUPSUpgradeable.sol';
import './openzeppelin_contracts_token_ERC20_IERC20.sol';
import './openzeppelin_contracts_token_ERC20_utils_SafeERC20.sol';
import './contracts_interfaces_ISubVault.sol';
import './contracts_interfaces_ITeller.sol';
import './contracts_interfaces_IPriceOracle.sol';

/**
 * @title USYC SubVault
 * @notice An upgradeable vault for managing USYC token and additional supported assets
 * @dev Implements UUPS upgradeability pattern with comprehensive security measures
 *
 * INHERITANCE STRUCTURE:
 * - Initializable: Base contract for upgradeable pattern
 * - UUPSUpgradeable: Implements upgradeability pattern
 * - AccessControlUpgradeable: Role-based access control
 * - PausableUpgradeable: Circuit breaker pattern
 * - ReentrancyGuardUpgradeable: Protection against reentrancy
 * - ISubVault: Core vault interface
 *
 * SECURITY CONSIDERATIONS:
 * 1. Upgradeability
 *    - UUPS pattern with access control
 *    - Storage gaps for future versions
 *    - Initializer protection
 *
 * 2. Access Control
 *    - Role-based permissions (DEFAULT_ADMIN_ROLE, ADMIN_ROLE)
 *    - Router authorization
 *    - Emergency admin controls
 *
 * 3. Asset Safety
 *    - Non-reentrant operations
 *    - SafeERC20 usage
 *    - Balance validations
 *    - Explicit approval management
 *
 * 4. Emergency Features
 *    - Pause functionality
 *    - Emergency mode with timelock
 *    - Protected withdrawal system
 *
 * STORAGE LAYOUT:
 * Careful consideration for storage layout is crucial for upgradeability.
 * Never modify existing storage variable order or size.
 * Always append new storage variables at the end.
 *
 * @custom:security-contact paras@zoth.io
 */
contract USYCSubVaultUpgradeable is
    Initializable,
    AccessControlUpgradeable,
    PausableUpgradeable,
    ReentrancyGuardUpgradeable,
    UUPSUpgradeable,
    ISubVault
{
    using SafeERC20 for IERC20;

    /// @dev Role definitions
    bytes32 public constant ADMIN_ROLE = keccak256('ADMIN_ROLE');

    /// @notice Core contract references
    address public router;

    /// @notice USYC token address
    /// @dev Primary asset of this vault
    address public USYC;
    address public teller;

    /// @notice Asset management mappings
    /// @dev Tracks USYC and secondary assets
    mapping(address => bool) public supportedAssets;
    address[] private _supportedAssetsList;

    /// @notice Emergency control settings
    /// @dev Timing and state management for emergency mode
    uint256 public constant EMERGENCY_DELAY = 1 hours;
    uint256 public lastEmergencyAction;
    bool public emergencyMode;

    // Add mapping for asset to oracle
    mapping(address => address) public assetOracles;

    event TellerUpdated(address indexed oldTeller, address indexed newTeller);

    /// @notice Ensures caller is authorized router
    /// @dev Prevents unauthorized access to core functions
    modifier onlyRouter() {
        if (msg.sender != router) revert UnauthorizedCaller(msg.sender);
        _;
    }

    /// @notice Ensures address is not zero
    /// @param addr Address to validate
    modifier validAddress(address addr) {
        if (addr == address(0)) revert InvalidAddress(addr);
        _;
    }

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    /// @notice Contract initializer (replaces constructor)
    /// @dev Sets up USYC vault with initial configuration
    /// @param _usyc Address of USYC token
    /// @param _router Address of router contract
    /// @param _admin Address of initial admin
    function initialize(address _usyc, address _router, address _admin) public initializer {
        require(_usyc != address(0), 'Invalid USYC address');
        require(_router != address(0), 'Invalid router address');
        require(_admin != address(0), 'Invalid admin address');

        // Initialize parent contracts
        __AccessControl_init();
        __Pausable_init();
        __ReentrancyGuard_init();

        // Set up roles
        _grantRole(DEFAULT_ADMIN_ROLE, _admin);
        _grantRole(ADMIN_ROLE, _admin);
        _setRoleAdmin(ADMIN_ROLE, DEFAULT_ADMIN_ROLE);

        // Initialize state variables
        USYC = _usyc;
        router = _router;

        // Set up USYC as primary asset
        supportedAssets[_usyc] = true;
        _supportedAssetsList.push(_usyc);
        emit AssetAdded(_usyc, 'USYC configured as primary asset');
    }

    // Add router setup function
    /// @notice Sets the router address
    /// @param _router Address of the router contract
    /// @dev Can only be set once by admin
    function setRouter(address _router) external onlyRole(ADMIN_ROLE) validAddress(_router) {
        router = _router;
        emit RouterSet(_router);
    }

    // Function to set oracle for an asset
    function setAssetOracle(address asset, address oracle) external onlyRole(ADMIN_ROLE) {
        require(asset != address(0), 'Invalid asset address');
        require(oracle != address(0), 'Invalid oracle address');
        assetOracles[asset] = oracle;
        emit AssetOracleSet(asset, oracle);
    }

    /// @notice Gets the oracle price for a supported asset
    /// @param asset Address of the asset to get price for
    /// @return price Current oracle price converted to uint256
    /// @return success Whether oracle price was successfully fetched
    function getOraclePrice(
        address asset
    ) external view override returns (uint256 price, bool success) {
        if (!supportedAssets[asset]) {
            return (0, false);
        }

        address oracle = assetOracles[asset];
        if (oracle == address(0)) {
            return (0, false);
        }

        try IPriceOracle(oracle).latestRoundData() returns (
            uint80 /*roundId*/,
            int256 answer,
            uint256 /*startedAt*/,
            uint256 updatedAt,
            uint80 /*answeredInRound*/
        ) {
            // Check if the price is positive
            if (answer <= 0) {
                return (0, false);
            }

            // Check for stale price
            if (block.timestamp - updatedAt > 24 hours) {
                // Configure timeout as needed
                return (0, false);
            }

            return (uint256(answer), true);
        } catch {
            return (0, false);
        }
    }

    /// @notice Handles deposit of supported assets
    /// @dev Routes to USYC or secondary asset handling
    /// @param user Address of depositing user
    /// @param asset Address of asset being deposited
    /// @param amount Amount to deposit
    /// @return success Whether deposit was successful
    function handleDeposit(
        address user,
        address asset,
        uint256 amount
    ) external override nonReentrant onlyRouter whenNotPaused returns (bool) {
        if (!supportedAssets[asset]) revert UnsupportedAsset(asset);
        if (amount == 0) revert InvalidAmount();
        if (emergencyMode) revert EmergencyModeEnabled(block.timestamp);

        _revokeApproval(asset, teller);
        _grantApproval(asset, teller, amount);

        try ITeller(teller).buy(amount / 1e4) returns (uint256) {
            emit SecondaryAssetOperation(asset, user, amount / 1e4, true);
            return true;
        } catch Error(string memory reason) {
            _revokeApproval(asset, teller);
            revert SecondaryAssetOperationFailed(reason);
        }
    }

    /// @notice Handles withdrawal of supported assets
    /// @dev Routes to USYC or secondary asset handling
    /// @param user Address of withdrawing user
    /// @param asset Address of asset being withdrawn
    /// @param amount Amount to withdraw
    /// @return success Whether withdrawal was successful
    function handleWithdraw(
        address user,
        address asset,
        uint256 amount
    ) external override nonReentrant onlyRouter whenNotPaused returns (bool) {
        if (!supportedAssets[asset]) revert UnsupportedAsset(asset);
        if (amount == 0) revert InvalidAmount();
        if (emergencyMode) revert EmergencyModeEnabled(block.timestamp);

        if (asset == USYC) {
            return _handleUSYCWithdraw(user, amount);
        } else {
            return _handleSecondaryAssetWithdraw(user, asset, amount);
        }
    }

    /// @notice Internal handler for USYC withdrawals
    /// @dev Withdraws USYC from FundVaultV2
    /// @param user User receiving withdrawal
    /// @param amount Amount being withdrawn
    /// @return success Whether operation succeeded
    function _handleUSYCWithdraw(address user, uint256 amount) internal returns (bool) {
        IERC20(USYC).safeTransfer(user, amount);
        emit PrimaryAssetOperation(user, amount, false);
        return true;
    }

    // / @notice Internal handler for secondary asset withdrawals
    // / @dev Handles non-USYC token withdrawals
    // / @param user User receiving withdrawal
    // / @param asset Asset being withdrawn
    // / @param amount Amount being withdrawn
    // / @return success Whether operation succeeded
    function _handleSecondaryAssetWithdraw(
        address user,
        address asset,
        uint256 amount
    ) internal returns (bool) {
        // try IFundVaultV2(USYC).redeem(amount, asset) returns (uint256 withdrawnAmount) {
        //     emit SecondaryAssetOperation(USYC, user, withdrawnAmount, false);
        //     return true;
        // } catch Error(string memory reason) {
        //     revert PrimaryAssetOperationFailed(reason);
        // }
    }

    /// @notice Adds support for a secondary asset
    /// @dev Cannot add USYC as it's already primary
    /// @param asset Asset address to add
    /// @param reason Reason for adding support
    function addAsset(
        address asset,
        string calldata reason
    ) external override onlyRole(ADMIN_ROLE) validAddress(asset) {
        if (asset == USYC) revert AssetAlreadySupported(asset);
        if (supportedAssets[asset]) revert AssetAlreadySupported(asset);

        supportedAssets[asset] = true;
        _supportedAssetsList.push(asset);
        emit AssetAdded(asset, reason);
    }

    /// @notice Removes support for a secondary asset
    /// @dev Cannot remove USYC
    /// @param asset Asset address to remove
    /// @param reason Reason for removal
    function removeAsset(
        address asset,
        string calldata reason
    ) external override onlyRole(ADMIN_ROLE) {
        if (asset == USYC) revert CannotRemovePrimaryAsset();
        if (!supportedAssets[asset]) revert UnsupportedAsset(asset);

        uint256 length = _supportedAssetsList.length;
        uint256 assetIndex = type(uint256).max;

        for (uint256 i = 0; i < length; i++) {
            if (_supportedAssetsList[i] == asset) {
                assetIndex = i;
                break;
            }
        }

        require(assetIndex != type(uint256).max, 'Asset not found');

        if (assetIndex != length - 1) {
            _supportedAssetsList[assetIndex] = _supportedAssetsList[length - 1];
        }
        _supportedAssetsList.pop();

        emit AssetRemoved(asset, reason);
    }

    /// @notice Enables emergency mode
    /// @dev Pauses operations and starts emergency timer
    function enableEmergencyMode() external override onlyRole(ADMIN_ROLE) whenNotPaused {
        emergencyMode = true;
        _pause();
        lastEmergencyAction = block.timestamp;
        emit EmergencyModeSet(block.timestamp, true);
    }

    /// @notice Disables emergency mode
    /// @dev Requires emergency delay to have passed
    function disableEmergencyMode() external override onlyRole(ADMIN_ROLE) {
        if (block.timestamp < lastEmergencyAction + EMERGENCY_DELAY)
            revert EmergencyDelayNotPassed();
        _unpause();
        emergencyMode = false;
        emit EmergencyModeSet(block.timestamp, false);
    }

    /// @notice Executes emergency withdrawal
    /// @dev Available only in emergency mode after delay
    /// @param asset Asset to withdraw
    /// @param to Recipient address
    /// @param amount Amount to withdraw
    /// @param reason Reason for withdrawal
    /// @return success Whether withdrawal succeeded
    function withdrawEmergency(
        address asset,
        address to,
        uint256 amount,
        string calldata reason
    ) external override nonReentrant onlyRole(ADMIN_ROLE) returns (bool) {
        if (!emergencyMode) revert EmergencyModeNotEnabled();
        if (block.timestamp < lastEmergencyAction + EMERGENCY_DELAY)
            revert EmergencyDelayNotPassed();
        if (amount == 0) revert InvalidAmount();
        if (!supportedAssets[asset]) revert UnsupportedAsset(asset);

        uint256 balance = IERC20(asset).balanceOf(address(this));
        uint256 withdrawAmount = amount > balance ? balance : amount;

        if (asset == USYC) {
            // Special handling for USYC emergency withdrawal
            _revokeApproval(USYC, address(USYC));
        }

        IERC20(asset).safeTransfer(to, withdrawAmount);

        lastEmergencyAction = block.timestamp;
        emit EmergencyWithdrawalExecuted(asset, to, withdrawAmount, reason);

        return true;
    }

    /**
     * @notice Sets the teller address
     * @dev Only callable by admin role
     * @param _teller New teller address
     */
    function setTeller(address _teller) external onlyRole(ADMIN_ROLE) {
        require(_teller != address(0), 'Zero address not allowed');
        require(_teller != teller, 'Same teller address');

        address oldTeller = teller;
        teller = _teller;
        emit TellerUpdated(oldTeller, _teller);
    }

    /// @notice Pauses vault operations
    /// @dev Admin only function
    function pause() external override onlyRole(ADMIN_ROLE) {
        _pause();
    }

    /// @notice Unpauses vault operations
    /// @dev Cannot unpause in emergency mode
    function unpause() external override onlyRole(ADMIN_ROLE) {
        if (emergencyMode) revert EmergencyModeEnabled(block.timestamp);
        _unpause();
    }

    /// @notice Grants approval for asset spending
    /// @dev Internal function for managing approvals
    /// @param asset Asset to approve
    /// @param spender Address to approve
    /// @param amount Amount to approve
    function _grantApproval(address asset, address spender, uint256 amount) internal {
        try IERC20(asset).approve(spender, amount) {
            emit ApprovalGranted(asset, spender, amount);
        } catch {
            revert ApprovalFailed(asset, spender);
        }
    }

    /// @notice Revokes approval for asset spending
    /// @dev Internal function for managing approvals
    /// @param asset Asset to revoke approval for
    /// @param spender Address to revoke approval from
    function _revokeApproval(address asset, address spender) internal {
        try IERC20(asset).approve(spender, 0) {
            emit ApprovalRevoked(asset, spender);
        } catch {
            revert ApprovalFailed(asset, spender);
        }
    }

    // View Functions

    /// @notice Gets list of supported assets
    /// @return Array of supported asset addresses
    function getSupportedAssets() external view override returns (address[] memory) {
        return _supportedAssetsList;
    }

    /// @notice Gets true for supported assets
    /// @return Whether the asset is supported
    function isAssetSupported(address asset) external view override returns (bool) {
        return supportedAssets[asset];
    }

    /// @notice Gets emergency status details
    /// @return isEmergencyMode Whether emergency mode is active
    /// @return isPaused Whether operations are paused
    /// @return timeUntilNextAction Time until next emergency action
    function getEmergencyStatus()
        external
        view
        override
        returns (bool isEmergencyMode, bool isPaused, uint256 timeUntilNextAction)
    {
        uint256 nextActionTime = lastEmergencyAction + EMERGENCY_DELAY;
        uint256 timeUntil = block.timestamp >= nextActionTime
            ? 0
            : nextActionTime - block.timestamp;

        return (emergencyMode, paused(), timeUntil);
    }

    /// @notice Checks if asset is USYC
    /// @param asset Asset to check
    /// @return bool Whether asset is USYC
    function isPrimaryAsset(address asset) external view override returns (bool) {
        return asset == USYC;
    }

    /// @notice Gets USYC address
    /// @return address USYC token address
    function getPrimaryAsset() external view override returns (address) {
        return USYC;
    }

    /// @notice Gets total supported assets count
    /// @return uint256 Number of supported assets (including USYC)
    function getSupportedAssetsCount() external view returns (uint256) {
        return _supportedAssetsList.length;
    }

    /// @notice Gets USYC balance
    /// @dev Returns the vault's USYC balance
    /// @return uint256 USYC balance
    function getUSYCBalance() external view returns (uint256) {
        return IERC20(USYC).balanceOf(address(this));
    }

    /// @notice Checks if operations are possible
    /// @dev Combines emergency and pause status
    /// @return bool Whether operations are possible
    function isOperational() external view returns (bool) {
        return !paused() && !emergencyMode;
    }

    /// @notice Gets vault statistics
    /// @dev Returns key vault metrics
    /// @return usycBalance Current USYC balance
    /// @return secondaryAssetCount Number of secondary assets
    /// @return isActive Whether vault is active
    function getVaultStats()
        external
        view
        returns (uint256 usycBalance, uint256 secondaryAssetCount, bool isActive)
    {
        return (
            IERC20(USYC).balanceOf(address(this)),
            _supportedAssetsList.length - 1, // Subtract 1 for USYC
            !paused() && !emergencyMode
        );
    }

    /**
     * @dev Function that should revert when msg.sender is not authorized to upgrade the contract
     * @param newImplementation Address of the new implementation contract
     */
    function _authorizeUpgrade(address newImplementation) internal override onlyRole(ADMIN_ROLE) {}
}
// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import { ERC4626Upgradeable, IERC4626 } from "./lib_openzeppelin-contracts-upgradeable_contracts_token_ERC20_extensions_ERC4626Upgradeable.sol";
import { IERC20 } from "./lib_openzeppelin-contracts_contracts_token_ERC20_IERC20.sol";
import { SafeERC20 } from "./lib_openzeppelin-contracts_contracts_token_ERC20_utils_SafeERC20.sol";
import { AccessControlUpgradeable } from "./lib_openzeppelin-contracts-upgradeable_contracts_access_AccessControlUpgradeable.sol";
import { UUPSUpgradeable } from "./lib_openzeppelin-contracts-upgradeable_contracts_proxy_utils_UUPSUpgradeable.sol";
import { ReentrancyGuardUpgradeable } from "./lib_openzeppelin-contracts-upgradeable_contracts_utils_ReentrancyGuardUpgradeable.sol";
import { IHedgeVault } from "./src_interfaces_IHedgeVault.sol";

/**
 * @title HedgeVault
 * @dev Vault contract for managing deposits and withdrawals
 */
contract HedgeVault is ERC4626Upgradeable, AccessControlUpgradeable, UUPSUpgradeable, ReentrancyGuardUpgradeable, IHedgeVault {
    using SafeERC20 for IERC20;

    bytes32 public constant SAY_TRADER_ROLE = keccak256("SAY_TRADER_ROLE");

    /*//////////////////////////////////////////////////////////////
                            STATE VARIABLES
    //////////////////////////////////////////////////////////////*/

    /// @notice Maximum amount that can be deposited across all users
    uint256 public override maxTotalDeposit;

    /// @notice Whether deposits are currently allowed
    bool public override depositsPaused;

    /// @notice Whether withdrawals are currently allowed
    bool public override withdrawalsPaused;

    /// @notice Amount currently being used by strategies
    uint256 public override fundsInTrading;

    /// @notice Total tracked balance of assets in the vault
    uint256 private _totalAssets;

    /// @notice Total deposits made by users, excluding PnL
    uint256 private _totalDeposits;

    /*//////////////////////////////////////////////////////////////
                                 EVENTS
    //////////////////////////////////////////////////////////////*/

    event StrategyFunded(address indexed strategy, uint256 amount);
    event StrategyReturned(address indexed strategy, uint256 amount, int256 pnl);
    event ControllerUpdated(address indexed newController);
    event DepositsStatusUpdated(bool paused);
    event WithdrawalsStatusUpdated(bool paused);
    event MaxTotalDepositUpdated(uint256 newMax);
    event TradingFundsWithdrawn(address indexed trader, uint256 amount);
    event TradingFundsReturned(address indexed trader, uint256 amount, int256 pnl);
    event DepositWithdrawalPaused();
    event DepositWithdrawalUnpaused();

    /*//////////////////////////////////////////////////////////////
                                 ERRORS
    //////////////////////////////////////////////////////////////*/

    error InvalidAddress();
    error InsufficientAvailableFunds();
    error InvalidAmount();
    error DepositsArePaused();
    error WithdrawalsArePaused();
    error MaxTotalDepositExceeded();

    /**
     * @dev Initializes the contract after it has been upgraded.
     */
    function initialize(address _asset, uint256 _maxTotalDeposit, address _owner) public override initializer {
        __ERC4626_init(IERC20(_asset));
        __ERC20_init("Hedge Vault Token", "HEDGE");
        __AccessControl_init();
        __UUPSUpgradeable_init();
        __ReentrancyGuard_init();

        if (address(_asset) == address(0) || _owner == address(0)) revert InvalidAddress();
        _grantRole(DEFAULT_ADMIN_ROLE, _owner);

        maxTotalDeposit = _maxTotalDeposit;
    }

    /*//////////////////////////////////////////////////////////////
                        CORE VAULT LOGIC
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Returns total assets including those currently in trading
     * @dev Uses internal accounting instead of balanceOf to prevent manipulation
     */
    function totalAssets() public view override(ERC4626Upgradeable, IHedgeVault) returns (uint256) {
        return _totalAssets;
    }
    /**
     * @notice Returns the total deposits made by users
     * @return Total deposits amount
     */

    function totalDeposits() public view override returns (uint256) {
        return _totalDeposits;
    }

    /**
     * @notice Calculates the current Profit and Loss (PnL)
     * @return Current PnL (can be positive or negative)
     */
    function currentPnL() public view returns (int256) {
        return int256(_totalAssets) - int256(_totalDeposits);
    }

    /**
     * @notice Deposits tokens into the vault
     * @dev Updates internal accounting of total assets
     */
    function deposit(uint256 assets, address receiver) public override(ERC4626Upgradeable, IHedgeVault) nonReentrant returns (uint256) {
        if (depositsPaused) revert DepositsArePaused();

        uint256 shares = super.deposit(assets, receiver);
        _totalAssets += assets;
        _totalDeposits += assets;
        return shares;
    }
    /**
     * @notice Mints vault shares
     * @dev Updates internal accounting of total assets
     */

    function mint(uint256 shares, address receiver) public override(ERC4626Upgradeable, IHedgeVault) nonReentrant returns (uint256) {
        if (depositsPaused) revert DepositsArePaused();

        uint256 actualAssets = super.mint(shares, receiver);
        _totalAssets += actualAssets;
        _totalDeposits += actualAssets;

        return actualAssets;
    }
    /**
     * @notice Withdraws tokens from the vault
     * @dev Updates internal accounting of total assets
     */

    function withdraw(uint256 assets, address receiver, address owner)
        public
        override(ERC4626Upgradeable, IHedgeVault)
        nonReentrant
        returns (uint256)
    {
        uint256 shares = super.withdraw(assets, receiver, owner);

        _totalAssets -= assets;
        unchecked {
            _totalDeposits = _totalDeposits > assets ? _totalDeposits - assets : 0;
        }

        return shares;
    }
    /**
     * @notice Redeems vault shares
     * @dev Updates internal accounting of total assets
     */

    function redeem(uint256 shares, address receiver, address owner)
        public
        override(ERC4626Upgradeable, IHedgeVault)
        nonReentrant
        returns (uint256)
    {
        uint256 assets = super.redeem(shares, receiver, owner);
        _totalAssets -= assets;
        unchecked {
            _totalDeposits = _totalDeposits > assets ? _totalDeposits - assets : 0;
        }
        return assets;
    }

    /**
     * @notice Returns the maximum amount of assets that can be deposited
     * @dev Overrides the EIP-4626 maxDeposit function to reflect vault's deposit limit
     * @return The maximum amount of assets that can be deposited
     */
    function maxDeposit(address) public view virtual override returns (uint256) {
        if (depositsPaused) return 0;

        uint256 remainingCapacity = maxTotalDeposit > _totalDeposits ? maxTotalDeposit - _totalDeposits : 0;

        return remainingCapacity;
    }

    /**
     * @notice Returns the maximum amount of shares that can be minted
     * @dev Overrides the EIP-4626 maxMint function to reflect vault's deposit limit
     * @return The maximum amount of shares that can be minted
     */
    function maxMint(address) public view virtual override returns (uint256) {
        if (depositsPaused) return 0;

        uint256 remainingCapacity = maxTotalDeposit > _totalDeposits ? maxTotalDeposit - _totalDeposits : 0;

        return convertToShares(remainingCapacity);
    }

    /**
     * @notice Returns the maximum amount of assets that can be withdrawn
     * @dev Overrides the EIP-4626 maxWithdraw function to reflect vault's withdrawal state
     * @return The maximum amount of assets that can be withdrawn
     */
    function maxWithdraw(address owner) public view virtual override returns (uint256) {
        // If withdrawals are paused, no withdrawals are allowed
        if (withdrawalsPaused || fundsInTrading != 0) return 0;
        return super.maxWithdraw(owner);
    }

    /**
     * @notice Returns the maximum amount of shares that can be redeemed
     * @dev Overrides the EIP-4626 maxRedeem function to reflect vault's withdrawal state
     * @return The maximum amount of shares that can be redeemed
     */
    function maxRedeem(address owner) public view virtual override returns (uint256) {
        // If withdrawals are paused, no redemptions are allowed
        if (withdrawalsPaused || fundsInTrading != 0) return 0;

        return super.maxRedeem(owner);
    }

    /**
     * @notice Previews the amount of shares received for a deposit
     * @dev Returns 0 if deposits are paused
     */
    function previewDeposit(uint256 assets) public view virtual override returns (uint256) {
        if (depositsPaused) return 0;
        return super.previewDeposit(assets);
    }

    /**
     * @notice Previews the amount of assets required to mint shares
     * @dev Returns 0 if deposits are paused
     */
    function previewMint(uint256 shares) public view virtual override returns (uint256) {
        if (depositsPaused) return 0;
        return super.previewMint(shares);
    }

    /**
     * @notice Previews the amount of assets received for a withdrawal
     * @dev Returns 0 if withdrawals are paused
     */
    function previewWithdraw(uint256 assets) public view virtual override returns (uint256) {
        if (withdrawalsPaused || fundsInTrading != 0) return 0;
        return super.previewWithdraw(assets);
    }

    /**
     * @notice Previews the amount of assets received for redeeming shares
     * @dev Returns 0 if withdrawals are paused
     */
    function previewRedeem(uint256 shares) public view virtual override returns (uint256) {
        if (withdrawalsPaused || fundsInTrading != 0) return 0;
        return super.previewRedeem(shares);
    }

    /*//////////////////////////////////////////////////////////////
                        STRATEGY FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Allows SAY_TRADER_ROLE to take funds for a trader
     * @param trader Address of the trader
     * @param amount Amount to take
     */
    function fundStrategy(address trader, uint256 amount) external override onlyRole(SAY_TRADER_ROLE) {
        // Check if enough available funds
        uint256 availableFunds = _totalAssets;
        if (amount > availableFunds) revert InsufficientAvailableFunds();

        fundsInTrading += amount;
        IERC20(asset()).safeTransfer(trader, amount);

        emit StrategyFunded(trader, amount);
    }

    /**
     * @notice Return funds from strategy with PnL
     * @param trader Address of the trader
     * @param amount Amount being returned
     * @param pnl Profit (positive) or loss (negative)
     */
    function returnStrategyFunds(address trader, uint256 amount, int256 pnl) external override onlyRole(SAY_TRADER_ROLE) {
        if (amount == 0) revert InvalidAmount();

        fundsInTrading -= amount;
        uint256 fundsToTransfer;
        if (pnl > 0) {
            fundsToTransfer = amount + uint256(pnl);
            _totalAssets += uint256(pnl);
        } else {
            fundsToTransfer = amount - uint256(-pnl);
            _totalAssets -= uint256(-pnl);
        }
        IERC20(asset()).safeTransferFrom(trader, address(this), fundsToTransfer);
        emit StrategyReturned(trader, amount, pnl);
    }
    /*//////////////////////////////////////////////////////////////
                            ADMIN FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Sets the maximum total deposit allowed
     * @param newMax New maximum total deposit
     */
    function setMaxTotalDeposit(uint256 newMax) external override onlyRole(DEFAULT_ADMIN_ROLE) {
        maxTotalDeposit = newMax;
        emit MaxTotalDepositUpdated(newMax);
    }

    /**
     * @notice Updates the withdrawal pause status
     * @param paused New pause status
     */
    function setWithdrawalsPaused(bool paused) external override onlyRole(DEFAULT_ADMIN_ROLE) {
        withdrawalsPaused = paused;
        emit WithdrawalsStatusUpdated(paused);
    }
    /**
     * @notice Updates the deposit pause status
     * @param paused New pause status
     */

    function setDepositsPaused(bool paused) external override onlyRole(DEFAULT_ADMIN_ROLE) {
        depositsPaused = paused;
        emit DepositsStatusUpdated(paused);
    }
    /**
     * @notice Pauses both deposits and withdrawals
     */

    function pauseAll() external override onlyRole(DEFAULT_ADMIN_ROLE) {
        depositsPaused = true;
        withdrawalsPaused = true;
        emit DepositWithdrawalPaused();
    }
    /**
     * @notice Unpauses both deposits and withdrawals
     */

    function unpauseAll() external override onlyRole(DEFAULT_ADMIN_ROLE) {
        depositsPaused = false;
        withdrawalsPaused = false;
        emit DepositWithdrawalUnpaused();
    }

    function _authorizeUpgrade(address) internal override onlyRole(DEFAULT_ADMIN_ROLE) { }
}
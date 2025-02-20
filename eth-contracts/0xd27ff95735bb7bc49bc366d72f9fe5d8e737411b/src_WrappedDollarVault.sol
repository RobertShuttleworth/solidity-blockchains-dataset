//SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

/* solhint-disable ordering */

import { Ownable2StepUpgradeable } from "./lib_openzeppelin-contracts-upgradeable_contracts_access_Ownable2StepUpgradeable.sol";
import { Ownable2StepUpgradeable } from "./lib_openzeppelin-contracts-upgradeable_contracts_access_Ownable2StepUpgradeable.sol";
import { Ownable2StepUpgradeable } from "./lib_openzeppelin-contracts-upgradeable_contracts_access_Ownable2StepUpgradeable.sol";
import { ERC20Upgradeable, IERC20 } from "./lib_openzeppelin-contracts-upgradeable_contracts_token_ERC20_ERC20Upgradeable.sol";
import { ERC20PermitUpgradeable } from "./lib_openzeppelin-contracts-upgradeable_contracts_token_ERC20_extensions_ERC20PermitUpgradeable.sol";
import { ERC20PausableUpgradeable } from "./lib_openzeppelin-contracts-upgradeable_contracts_token_ERC20_extensions_ERC20PausableUpgradeable.sol";
import { SafeERC20 } from "./lib_openzeppelin-contracts-upgradeable_lib_openzeppelin-contracts_contracts_token_ERC20_utils_SafeERC20.sol";
import { IERC4626 } from "./lib_openzeppelin-contracts-upgradeable_lib_openzeppelin-contracts_contracts_interfaces_IERC4626.sol";
import { Math } from "./lib_openzeppelin-contracts-upgradeable_lib_openzeppelin-contracts_contracts_utils_math_Math.sol";
import { ReentrancyGuardUpgradeable } from "./lib_openzeppelin-contracts-upgradeable_contracts_utils_ReentrancyGuardUpgradeable.sol";
import { ERC4626Upgradeable } from "./lib_openzeppelin-contracts-upgradeable_contracts_token_ERC20_extensions_ERC4626Upgradeable.sol";

using Math for uint256; // only used for `mulDiv` operations.
using SafeERC20 for IERC20; // `safeTransfer` and `safeTransferFrom`

contract WrappedDollarVault is
    Ownable2StepUpgradeable,
    ERC4626Upgradeable,
    ERC20PermitUpgradeable,
    ERC20PausableUpgradeable,
    ReentrancyGuardUpgradeable
{
    /*
     * ##########
     * # STATE #
     * ##########
     */

    /// @notice underlying asset must be an ERC4626, with USD based underlying,
    /// i.e. sUSDe, with USDe as underlying.
    IERC4626 internal _asset; // underlying asset is an ERC4626

    /// @notice divisor for management fee calculation, 100% = 10_000_000 µbps
    /// (microbips)
    uint256 public constant MICROBPS_DIVIDER = 10_000_000;

    /// @notice treasury address to collect fees
    address public treasury;

    /// @notice timestamp of the last fee collection
    uint256 public lastFeeCollectionTimestamp;

    /// @notice USD value per share at the time of the last fee collection,
    /// including accrued fees
    uint256 public lastFeeCollectionUsdValuePerShareIncludingAccruedFees;

    /// @notice current management fee, in µbps (microbips)
    uint256 public managementFeeMicrobps;

    /// @notice router contract addresses that can bypass routing restrictions
    mapping(address router => bool isActive) public routers;

    /// @notice when true, only router can call deposit/withdraw functions
    bool public routingRestricted;

    /*
     * ##########
     * # ERRORS #
     * ##########
     */
    /// @notice error thrown when the USD share value has decreased after an
    /// operation
    error ShareValueDecreasedAfterOperation();

    /// @notice error thrown when the management fee is not within 0-10%
    error InvalidManagementFee();

    /// @notice error thrown when caller is not the router during restricted
    /// routing
    error CallerNotAuthorizedRouter();

    /*
     * ##########
     * # EVENTS #
     * ##########
     */
    /// @notice event emitted when fees are collected
    event FeesCollected(
        address indexed treasury, uint256 usdAmount, uint256 assetAmount
    );

    /// @notice event emitted when routing restrictions are toggled
    event RoutingRestrictedToggled(bool restricted);

    /// @notice event emitted when the router is updated
    event RouterUpdated(address indexed router, bool isActive);

    /*
     * ##########
     * # INIT #
     * ##########
     */
    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    /// @notice initialize the vault
    /// @param owner The owner of the vault
    /// @param _underlyingAsset The underlying asset
    /// @param name The name of the vault
    /// @param symbol The symbol of the vault
    /// @param _treasury The treasury address
    function initialize(
        address owner,
        address _underlyingAsset,
        string memory name,
        string memory symbol,
        address _treasury
    )
        public
        virtual
        initializer
    {
        __ERC20_init(name, symbol);
        __Ownable_init(owner);
        __ERC20Permit_init(name);
        __ERC20Pausable_init();
        __ERC4626_init(IERC20(_underlyingAsset));
        _asset = IERC4626(_underlyingAsset);
        managementFeeMicrobps = 450_000; // 4.5% default management fee
        routingRestricted = true;
        // Mint 100 shares to dead address to prevent share price manipulation
        _mint(address(0x000000000000000000000000000000000000dEaD), 100e18);
        lastFeeCollectionTimestamp = block.timestamp;
        lastFeeCollectionUsdValuePerShareIncludingAccruedFees =
            usdValuePerShareIncludingAccruedFees();
        treasury = _treasury;
        __ReentrancyGuard_init();
    }

    /*
     * ##########
     * # MODIFIERS #
     * ##########
     */

    /// @notice modifier to check if the USD share value has decreased after
    /// an operation
    modifier _checkShareValueHasNotDecreased() {
        uint256 oldShareValue = usdValuePerShare();
        _;
        uint256 newShareValue = usdValuePerShare();
        if (newShareValue < oldShareValue) {
            revert ShareValueDecreasedAfterOperation();
        }
    }

    /// @notice modifier to check if caller is allowed to route transactions
    modifier checkRouter() {
        if (routingRestricted && !routers[msg.sender]) {
            revert CallerNotAuthorizedRouter();
        }
        _;
    }

    /*
     * ##########
     * # OWNER #
     * ##########
     */

    /// @notice pause the vault
    function pause() external onlyOwner nonReentrant {
        _pause();
    }

    /// @notice unpause the vault
    function unpause() external onlyOwner nonReentrant {
        _unpause();
    }

    /// @notice manually collect fees, will be called automatically as users
    /// deposit and withdraw
    function collectFees()
        external
        onlyOwner
        nonReentrant
        whenNotPaused
        _checkShareValueHasNotDecreased
    {
        _collectFees();
    }

    /// @notice set the management fee
    /// @param newFeeMicrobps The new management fee in µbps (microbips)
    function setManagementFee(uint256 newFeeMicrobps)
        external
        onlyOwner
        nonReentrant
        _checkShareValueHasNotDecreased
    {
        _collectFees();
        // Ensure fee is not more than 10% (1_000_000 µbps)
        if (newFeeMicrobps > 1_000_000) revert InvalidManagementFee();
        managementFeeMicrobps = newFeeMicrobps;
    }

    /// @notice Add or remove a router
    /// @param _router The router address to modify
    /// @param isActive Whether the router should be active
    function setRouter(
        address _router,
        bool isActive
    )
        public
        onlyOwner
        nonReentrant
    {
        routers[_router] = isActive;
        emit RouterUpdated(_router, isActive);
    }

    /// @notice Toggle routing restrictions
    /// @param restricted Whether routing should be restricted to router only
    function setRoutingRestricted(bool restricted)
        external
        onlyOwner
        nonReentrant
    {
        routingRestricted = restricted;
        emit RoutingRestrictedToggled(restricted);
    }

    /*
     * ##########
     * # VIEWS #
     * ##########
     */

    /// @notice Total USD value of the vault, including accrued fees.
    function totalUsdValueIncludingAccruedFees()
        public
        view
        returns (uint256)
    {
        return _asset.previewRedeem(super.totalAssets());
    }

    /// @notice USD value per share, not deducting accrued fees.
    /// Not representative of value of a share, for that use
    /// `usdValuePerShare()`
    function usdValuePerShareIncludingAccruedFees()
        public
        view
        returns (uint256)
    {
        return totalUsdValueIncludingAccruedFees() * 1e18 / totalSupply();
    }

    /// @notice Single source of truth for the accrued fees vault owes treasury.
    /// Denominated in USD.
    function accruedFeesUSD() public view returns (uint256) {
        uint256 currentUSDValueIncludingAccruedFees =
            totalUsdValueIncludingAccruedFees();
        uint256 _totalSupply = totalSupply();

        // Calculate per-share values
        uint256 currentUSDValuePerShareIncludingAccruedFees =
            currentUSDValueIncludingAccruedFees * 1e18 / _totalSupply;

        // Calculate growth based on per-share value
        uint256 usdValueGrowthPerShare = 0;
        if (
            currentUSDValuePerShareIncludingAccruedFees
                > lastFeeCollectionUsdValuePerShareIncludingAccruedFees
        ) {
            usdValueGrowthPerShare = currentUSDValuePerShareIncludingAccruedFees
                - lastFeeCollectionUsdValuePerShareIncludingAccruedFees;
        }

        // If no per-share growth, no fees
        if (usdValueGrowthPerShare == 0) return 0;

        uint256 timeDelta = block.timestamp - lastFeeCollectionTimestamp;

        // Calculate management fee on current total value
        uint256 usdFeesToCollect = currentUSDValueIncludingAccruedFees
            * managementFeeMicrobps * timeDelta / (365 days * MICROBPS_DIVIDER);

        // Cap fee at total growth (per-share growth * current supply)
        uint256 totalGrowthCap = usdValueGrowthPerShare * _totalSupply / 1e18;
        usdFeesToCollect = usdFeesToCollect > totalGrowthCap
            ? totalGrowthCap
            : usdFeesToCollect;

        return usdFeesToCollect;
    }

    /// @notice Accrued fees denominated in underlying asset units, not USD.
    function accruedFeesInAssetUnits() public view returns (uint256) {
        uint256 _accruedFeesUSD = accruedFeesUSD();
        // Convert fees to underlying assets instead of USD, rounding down
        return _asset.previewDeposit(_accruedFeesUSD);
    }

    /// @notice Total assets of the vault, subtracting accrued fees. Denominated
    /// in
    /// underlying asset units, not USD.
    function totalAssets() public view virtual override returns (uint256) {
        uint256 currentAssetsIncludingAccruedFees = super.totalAssets();
        return currentAssetsIncludingAccruedFees - accruedFeesInAssetUnits();
    }

    /**
     * @notice Returns the USD value of one share
     * @return The USD value of one share, scaled to 18 decimals
     */
    function usdValuePerShare() public view returns (uint256) {
        return _asset.previewRedeem(totalAssets()) * 1e18 / totalSupply();
    }

    /// @notice decimals of the vault
    function decimals()
        public
        view
        virtual
        override(ERC20Upgradeable, ERC4626Upgradeable)
        returns (uint8)
    {
        return 18;
    }

    /*
     * ##########
     * # PUBLIC #
     * ##########
     */

    /**
     * @dev See {IERC4626-deposit}
     * @notice The `deposit` function is used to deposit underlying assets into
     * the vault.
     * @param assets The underlying assets amount to be converted into shares.
     * @param receiver The address of the shares receiver.
     * @return Amount of shares received in exchange of the
     * specified underlying assets amount.
     */
    function deposit(
        uint256 assets,
        address receiver
    )
        public
        virtual
        override
        whenNotPaused
        nonReentrant
        checkRouter
        returns (uint256)
    {
        return super.deposit(assets, receiver);
    }

    /**
     * @dev The `withdraw` function is used to withdraw the specified underlying
     * assets amount in exchange of a proportional amount of shares.
     * @param assets The underlying assets amount to be converted into shares.
     * @param receiver The address of the shares receiver.
     * @param owner The address of the owner.
     * @return Amount of shares received in exchange of the specified underlying
     * assets amount.
     */
    function withdraw(
        uint256 assets,
        address receiver,
        address owner
    )
        public
        virtual
        override
        whenNotPaused
        nonReentrant
        checkRouter
        returns (uint256)
    {
        return super.withdraw(assets, receiver, owner);
    }

    /**
     * @dev The `mint` function is used to mint the specified amount of shares
     * in exchange of the corresponding assets amount from owner.
     * @param shares The shares amount to be converted into underlying assets.
     * @param receiver The address of the shares receiver.
     * @return Amount of underlying assets deposited in exchange of the
     * specified amount of shares.
     */
    function mint(
        uint256 shares,
        address receiver
    )
        public
        virtual
        override
        whenNotPaused
        nonReentrant
        checkRouter
        returns (uint256)
    {
        return super.mint(shares, receiver);
    }

    /**
     * @dev The `redeem` function is used to redeem the specified amount of
     * shares in exchange of the corresponding underlying assets amount from
     * owner.
     * @param shares The shares amount to be converted into underlying assets.
     * @param receiver The address of the shares receiver.
     * @param owner The address of the owner.
     * @return Amount of underlying assets received in exchange of the specified
     * amount of shares.
     */
    function redeem(
        uint256 shares,
        address receiver,
        address owner
    )
        public
        virtual
        override
        whenNotPaused
        nonReentrant
        checkRouter
        returns (uint256)
    {
        return super.redeem(shares, receiver, owner);
    }

    /*
     * ##########
     * # INTERNAL #
     * ##########
     */

    /**
     * @dev The `_deposit` function is used to deposit the specified underlying
     * assets amount in exchange of a proportional amount of shares.
     * @param caller The address of the caller.
     * @param receiver The address of the shares receiver.
     * @param assets The underlying assets amount to be converted into shares.
     * @param shares The shares amount to be converted into underlying assets.
     */
    function _deposit(
        address caller,
        address receiver,
        uint256 assets,
        uint256 shares
    )
        internal
        virtual
        override
        _checkShareValueHasNotDecreased
    {
        _collectFees();
        super._deposit(caller, receiver, assets, shares);
    }

    /**
     * @dev The function `_withdraw` is used to withdraw the specified
     * underlying assets amount in exchange of a proportionnal amount of shares
     * by
     * specifying all the params.
     * @notice The `withdraw` function is used to withdraw the specified
     * underlying assets amount in exchange of a proportionnal amount of shares.
     * @param receiver The address of the shares receiver.
     * @param owner The address of the owner.
     * @param assets The underlying assets amount to be converted into shares.
     * @param shares The shares amount to be converted into underlying assets.
     */
    function _withdraw(
        address caller,
        address receiver,
        address owner,
        uint256 assets,
        uint256 shares
    )
        internal
        virtual
        override
        _checkShareValueHasNotDecreased
    {
        _collectFees();
        super._withdraw(caller, receiver, owner, assets, shares);
    }

    /// @notice internal ERC20 function to update the balances
    /// @param from The address of the sender
    /// @param to The address of the receiver
    /// @param value The amount of tokens to be transferred
    function _update(
        address from,
        address to,
        uint256 value
    )
        internal
        virtual
        override(ERC20Upgradeable, ERC20PausableUpgradeable)
    {
        ERC20PausableUpgradeable._update(from, to, value);
    }

    /// @notice collect fees to treasury, called automatically as users deposit
    /// and withdraw
    function _collectFees() internal {
        uint256 _accruedFeesUSD = accruedFeesUSD();
        uint256 _accruedFeesAssetUnits = _asset.previewDeposit(_accruedFeesUSD);
        lastFeeCollectionTimestamp = block.timestamp;
        lastFeeCollectionUsdValuePerShareIncludingAccruedFees =
            usdValuePerShareIncludingAccruedFees();
        address _treasury = treasury;
        if (_accruedFeesAssetUnits > 0) {
            _asset.transfer(_treasury, _accruedFeesAssetUnits);
        }
        emit FeesCollected(_treasury, _accruedFeesUSD, _accruedFeesAssetUnits);
    }
}
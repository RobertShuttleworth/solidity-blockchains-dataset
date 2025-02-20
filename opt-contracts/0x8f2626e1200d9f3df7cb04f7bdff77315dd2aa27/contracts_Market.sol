// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0 <0.9.0;

import {Initializable} from "./openzeppelin_contracts-upgradeable_proxy_utils_Initializable.sol";
import {AccessControlUpgradeable} from "./openzeppelin_contracts-upgradeable_access_AccessControlUpgradeable.sol";
import {UUPSUpgradeable} from "./openzeppelin_contracts-upgradeable_proxy_utils_UUPSUpgradeable.sol";
import {IERC20Metadata} from "./openzeppelin_contracts_token_ERC20_extensions_IERC20Metadata.sol";
import {SafeERC20, IERC20} from "./openzeppelin_contracts_token_ERC20_utils_SafeERC20.sol";

import {IRemoteHub, IXusdToken, IExchange, IWrappedXusdToken, IMarket} from "./contracts_interfaces_IRemoteHub.sol";

contract Market is IMarket, Initializable, AccessControlUpgradeable, UUPSUpgradeable {

    using SafeERC20 for IERC20;

    IERC20 public assetToken;
    IRemoteHub public remoteHub;
    address private DELETED_0;
    address private DELETED_1;

    // --- events

    event RemoteHubUpdated(address remoteHub);
    event MarketUpdatedTokens(address assetToken);
    event Wrap(address asset, uint256 amount, address receiver, uint256 wrappedXusdAmount);
    event Unwrap(address asset, uint256 amount, address receiver, uint256 unwrappedXusdAmount);
    error AssetNotFound(address asset);

    // ---  initializer

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    function UPGRADER_ROLE() public pure returns(bytes32) {
        return keccak256("UPGRADER_ROLE");
    }

    function initialize(address _remoteHub) initializer public {
        __AccessControl_init();
        __UUPSUpgradeable_init();

        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _grantRole(UPGRADER_ROLE(), msg.sender);

        remoteHub = IRemoteHub(_remoteHub);
    }

    function _authorizeUpgrade(address newImplementation) internal onlyUpgrader override {}

    // ---  remoteHub getters

    function xusd() internal view returns(IXusdToken) {
        return remoteHub.xusd();
    }

    function wrappedXusd() internal view returns(IWrappedXusdToken) {
        return remoteHub.wxusd();
    }

    function exchange() internal view returns(IExchange) {
        return remoteHub.exchange();
    }

    // ---  modifiers

    modifier onlyUpgrader() {
        require(hasRole(UPGRADER_ROLE(), msg.sender), "Caller doesn't have UPGRADER_ROLE role");
        _;
    }

    // --- setters

    function setRemoteHub(address _remoteHub) external onlyUpgrader {
        require(_remoteHub != address(0), "Zero address not allowed");
        remoteHub = IRemoteHub(_remoteHub);
        emit RemoteHubUpdated(_remoteHub);
    }

    function setToken(address _assetToken) external onlyUpgrader {
        require(_assetToken != address(0), "Zero address not allowed");
        assetToken = IERC20(_assetToken);
        emit MarketUpdatedTokens(_assetToken);
    }

    // --- logic

    /**
     * @dev preview wrap `amount` of `asset` to wxUSD.
     *
     * This is an estimate amount, real amount may vary.
     *
     * Requirements:
     *
     * - `asset` cannot be the zero address.
     * - `amount` cannot be the zero.
     */
    function previewWrap(address asset, uint256 amount) external view override returns (uint256) {
        require(asset != address(0), "Zero address for asset not allowed");
        require(amount != 0, "Zero amount not allowed");

        IExchange _exchange = exchange();
        IWrappedXusdToken _wrappedXusd = wrappedXusd();
        IXusdToken _xusd = xusd();

        if (asset == address(assetToken)) {
            uint256 buyFeeAmount = (amount * _exchange.buyFee()) / _exchange.buyFeeDenominator();
            return _wrappedXusd.previewDeposit(amount - buyFeeAmount);
        } else if (asset == address(_xusd)) {
            return _wrappedXusd.previewDeposit(amount);
        } else {
            revert AssetNotFound(asset);
        }
    }

    /**
     * @dev preview unwrap `amount` of wxUSD to `asset`.
     *
     * This is an estimate amount, real amount may vary.
     *
     * Requirements:
     *
     * - `asset` cannot be the zero address.
     * - `amount` cannot be the zero.
     */
    function previewUnwrap(address asset, uint256 amount) external view override returns (uint256) {
        require(asset != address(0), "Zero address for asset not allowed");
        require(amount != 0, "Zero amount not allowed");

        IExchange _exchange = exchange();
        IWrappedXusdToken _wrappedXusd = wrappedXusd();
        IXusdToken _xusd = xusd();

        if (asset == address(assetToken)) {
            uint256 xusdAmount = _wrappedXusd.previewRedeem(amount);
            uint256 redeemFeeAmount = (xusdAmount * _exchange.redeemFee()) / _exchange.redeemFeeDenominator();
            return xusdAmount - redeemFeeAmount;
        } else if (asset == address(_xusd)) {
            return _wrappedXusd.previewRedeem(amount);
        } else {
            revert AssetNotFound(asset);
        }
    }

    /**
     * @dev Wrap `amount` of `asset` from `msg.sender` to wxUSD of `receiver`.
     *
     * Emits a {Wrap} event.
     *
     * Requirements:
     *
     * - `asset` cannot be the zero address.
     * - `amount` cannot be the zero.
     * - `receiver` cannot be the zero address.
     */
    function wrap(address asset, uint256 amount, address receiver) external override returns (uint256) {
        require(asset != address(0), "Zero address for asset not allowed");
        require(amount != 0, "Zero amount not allowed");
        require(receiver != address(0), "Zero address for receiver not allowed");

        IExchange _exchange = exchange();
        IWrappedXusdToken _wrappedXusd = wrappedXusd();
        IXusdToken _xusd = xusd();

        uint256 wrappedXusdAmount;
        if (asset == address(assetToken)) {
            assetToken.safeTransferFrom(msg.sender, address(this), amount);

            assetToken.approve(address(_exchange), 0); // because of race condition fix
            assetToken.approve(address(_exchange), amount);
            uint256 xusdAmount = _exchange.buy(asset, amount);

            _xusd.approve(address(_wrappedXusd), xusdAmount);
            wrappedXusdAmount = _wrappedXusd.deposit(xusdAmount, receiver);

        } else if (asset == address(_xusd)) {
            IERC20(address(_xusd)).safeTransferFrom(msg.sender, address(this), amount);

            _xusd.approve(address(_wrappedXusd), amount);
            wrappedXusdAmount = _wrappedXusd.deposit(amount, receiver);

        } else {
            revert AssetNotFound(asset);
        }

        emit Wrap(asset, amount, receiver, wrappedXusdAmount);

        return wrappedXusdAmount;
    }

    /**
     * @dev Unwrap `amount` of wxUSD from `msg.sender` to `asset` of `receiver`.
     *
     * Emits a {Unwrap} event.
     *
     * Requirements:
     *
     * - `asset` cannot be the zero address.
     * - `amount` cannot be the zero.
     * - `receiver` cannot be the zero address.
     */
    function unwrap(address asset, uint256 amount, address receiver) external override returns (uint256) {
        require(asset != address(0), "Zero address for asset not allowed");
        require(amount != 0, "Zero amount not allowed");
        require(receiver != address(0), "Zero address for receiver not allowed");

        IExchange _exchange = exchange();
        IWrappedXusdToken _wrappedXusd = wrappedXusd();
        IXusdToken _xusd = xusd();

        uint256 unwrappedXusdAmount;
        if (asset == address(assetToken)) {
            IERC20(address(_wrappedXusd)).safeTransferFrom(msg.sender, address(this), amount);

            _wrappedXusd.approve(address(_wrappedXusd), amount);
            uint256 xusdAmount = _wrappedXusd.redeem(amount, address(this), address(this));

            _xusd.approve(address(_exchange), xusdAmount);
            unwrappedXusdAmount = _exchange.redeem(asset, xusdAmount);

            assetToken.safeTransfer(receiver, unwrappedXusdAmount);

        } else if (asset == address(_xusd)) {
            IERC20(address(_wrappedXusd)).safeTransferFrom(msg.sender, address(this), amount);
            _wrappedXusd.approve(address(_wrappedXusd), amount);

            unwrappedXusdAmount = _wrappedXusd.redeem(amount, receiver, address(this));
        } else {
            revert AssetNotFound(asset);
        }

        emit Unwrap(asset, amount, receiver, unwrappedXusdAmount);

        return unwrappedXusdAmount;
    }

}
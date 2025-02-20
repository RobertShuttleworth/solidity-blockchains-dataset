// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0 <0.9.0;

import { ERC20Upgradeable } from "./openzeppelin_contracts-upgradeable_token_ERC20_ERC20Upgradeable.sol";
import { AccessControlUpgradeable } from "./openzeppelin_contracts-upgradeable_access_AccessControlUpgradeable.sol";
import { UUPSUpgradeable } from "./openzeppelin_contracts-upgradeable_proxy_utils_UUPSUpgradeable.sol";
import { SafeERC20, IERC20 } from "./openzeppelin_contracts_token_ERC20_utils_SafeERC20.sol";

import { WadRayMath } from "./contracts_libraries_WadRayMath.sol";
import { IRemoteHub, IXusdToken, IRoleManager } from "./contracts_interfaces_IRemoteHub.sol";
import { NonRebaseInfo } from "./contracts_interfaces_IPayoutManager.sol";
import { IERC4626 } from "./contracts_interfaces_IERC4626.sol";

import "./hardhat_console.sol";

// Because of upgradeable contracts, we cannot use PausableUpgradeable (whenNotPaused modifier)

contract WrappedXusdToken is IERC4626, ERC20Upgradeable, AccessControlUpgradeable, UUPSUpgradeable {
    using WadRayMath for uint256;
    using SafeERC20 for IERC20;

    IRemoteHub private remoteHub;
    uint8 private _decimals;
    bool public paused;

    // ---  events

    event RemoteHubUpdated(address remoteHub);
    event Paused();
    event Unpaused();

    // ---  initializer

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    function UPGRADER_ROLE() public pure returns (bytes32) {
        return keccak256("UPGRADER_ROLE");
    }

    /**
     * @notice Initializes the contract
     * @param name The name of the token
     * @param symbol The symbol of the token
     * @param newDecimals The number of decimals for the token
     * @param _remoteHub The address of the remote hub
     */
    function initialize(string calldata name, string calldata symbol, uint8 newDecimals, address _remoteHub) public initializer {
        __ERC20_init(name, symbol);
        __AccessControl_init();
        __UUPSUpgradeable_init();

        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _grantRole(UPGRADER_ROLE(), msg.sender);

        _decimals = newDecimals;
        remoteHub = IRemoteHub(_remoteHub);
    }

    function _authorizeUpgrade(address newImplementation) internal override onlyUpgrader {}

    receive() external payable {}

    // ---  remoteHub getters

    function roleManager() internal view returns (IRoleManager) {
        return remoteHub.roleManager();
    }

    function xusd() internal view returns (IXusdToken) {
        return remoteHub.xusd();
    }

    // ---  modifiers

    modifier whenNotPaused() {
        require(paused == false, "pause");
        _;
    }

    modifier onlyPortfolioAgent() {
        IRoleManager _roleManager = roleManager();
        require(
            _roleManager.hasRole(_roleManager.PORTFOLIO_AGENT_ROLE(), msg.sender),
            "Caller doesn't have PORTFOLIO_AGENT_ROLE role"
        );
        _;
    }

    modifier onlyCCIP() {
        require(remoteHub.ccipPool() == msg.sender, "Caller is not the CCIP pool");
        _;
    }

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

    // ---  logic

    /**
     * @notice Pauses the contract
     */
    function pause() public onlyPortfolioAgent {
        paused = true;
        emit Paused();
    }

    /**
     * @notice Unpauses the contract
     */
    function unpause() public onlyPortfolioAgent {
        paused = false;
        emit Unpaused();
    }

    /// @inheritdoc ERC20Upgradeable
    function decimals() public view override(ERC20Upgradeable) returns (uint8) {
        return _decimals;
    }

    /// @inheritdoc IERC4626
    function totalAssets() external view override returns (uint256) {
        return _convertToAssetsDown(totalSupply());
    }

    /// @inheritdoc IERC4626
    function convertToShares(uint256 assets) external view override returns (uint256) {
        return _convertToSharesDown(assets);
    }

    /// @inheritdoc IERC4626
    function convertToAssets(uint256 shares) external view override returns (uint256) {
        return _convertToAssetsDown(shares);
    }

    /// @inheritdoc IERC4626
    function maxDeposit(address receiver) external view override returns (uint256) {
        return type(uint256).max;
    }

    /// @inheritdoc IERC4626
    function previewDeposit(uint256 assets) external view override returns (uint256) {
        return _convertToSharesDown(assets);
    }

    /// @inheritdoc IERC4626
    function deposit(uint256 assets, address receiver) external override whenNotPaused returns (uint256) {
        require(assets != 0, "Zero assets not allowed");
        require(receiver != address(0), "Zero address for receiver not allowed");

        IERC20(address(xusd())).safeTransferFrom(msg.sender, address(this), assets);

        uint256 shares = _convertToSharesDown(assets);

        if (shares != 0) {
            _mint(receiver, shares);
        }

        emit Deposit(msg.sender, receiver, assets, shares);

        return shares;
    }

    /// @inheritdoc IERC4626
    function maxMint(address receiver) external view override returns (uint256) {
        return type(uint256).max;
    }

    /// @inheritdoc IERC4626
    function previewMint(uint256 shares) external view override returns (uint256) {
        return _convertToAssetsUp(shares);
    }

    /**
     * @notice Mints shares to an account (only callable by CCIP)
     * @param account The address to receive the minted shares
     * @param amount The amount of shares to mint
     */
    function mint(address account, uint256 amount) external whenNotPaused onlyCCIP {
        uint256 shares = amount;
        uint256 assets = _convertToAssetsUp(shares);
        xusd().mint(address(this), assets);
        _mint(account, shares);
    }

    /**
     * @notice Burns shares from the caller (only callable by CCIP)
     * @param amount The amount of shares to burn
     */
    function burn(uint256 amount) external whenNotPaused onlyCCIP {
        uint256 shares = amount;
        _burn(msg.sender, shares);
        uint256 assets = _convertToAssetsDown(shares);
        xusd().burn(address(this), assets);
    }

    /// @inheritdoc IERC4626
    function mint(uint256 shares, address receiver) external override whenNotPaused returns (uint256) {
        require(shares != 0, "Zero shares not allowed");
        require(receiver != address(0), "Zero address for receiver not allowed");

        uint256 assets = _convertToAssetsUp(shares);

        if (assets != 0) {
            IERC20(address(xusd())).safeTransferFrom(msg.sender, address(this), assets);
        }

        _mint(receiver, shares);

        emit Deposit(msg.sender, receiver, assets, shares);

        return assets;
    }

    /// @inheritdoc IERC4626
    function maxWithdraw(address owner) external view override returns (uint256) {
        return _convertToAssetsDown(balanceOf(owner));
    }

    /// @inheritdoc IERC4626
    function previewWithdraw(uint256 assets) external view override returns (uint256) {
        return _convertToSharesUp(assets);
    }

    /// @inheritdoc IERC4626
    function withdraw(uint256 assets, address receiver, address owner) external override whenNotPaused returns (uint256) {
        require(assets != 0, "Zero assets not allowed");
        require(receiver != address(0), "Zero address for receiver not allowed");
        require(owner != address(0), "Zero address for owner not allowed");

        uint256 shares = _convertToSharesUp(assets);

        if (owner != msg.sender) {
            uint256 currentAllowance = allowance(owner, msg.sender);
            require(currentAllowance >= shares, "Withdraw amount exceeds allowance");
            _approve(owner, msg.sender, currentAllowance - shares);
        }

        if (shares != 0) {
            _burn(owner, shares);
        }

        IERC20(address(xusd())).safeTransfer(receiver, assets);

        emit Withdraw(msg.sender, receiver, owner, assets, shares);

        return shares;
    }

    /// @inheritdoc IERC4626
    function maxRedeem(address owner) external view override returns (uint256) {
        return balanceOf(owner);
    }

    /// @inheritdoc IERC4626
    function previewRedeem(uint256 shares) external view override returns (uint256) {
        return _convertToAssetsDown(shares);
    }

    /// @inheritdoc IERC4626
    function redeem(uint256 shares, address receiver, address owner) external override whenNotPaused returns (uint256) {
        require(shares != 0, "Zero shares not allowed");
        require(receiver != address(0), "Zero address for receiver not allowed");
        require(owner != address(0), "Zero address for owner not allowed");

        if (owner != msg.sender) {
            uint256 currentAllowance = allowance(owner, msg.sender);
            require(currentAllowance >= shares, "Redeem amount exceeds allowance");
            _approve(owner, msg.sender, currentAllowance - shares);
        }

        _burn(owner, shares);

        uint256 assets = _convertToAssetsDown(shares);

        if (assets != 0) {
            IERC20(address(xusd())).safeTransfer(receiver, assets);
        }

        emit Withdraw(msg.sender, receiver, owner, assets, shares);

        return assets;
    }

    /**
     * @notice Returns the current exchange rate between shares and assets
     * @return uint256 The current rate
     */
    function rate() public view returns (uint256) {
        return 10 ** 54 / xusd().rebasingCreditsPerTokenHighres();
    }

    function _convertToSharesUp(uint256 assets) internal view returns (uint256) {
        return assets.rayDiv(rate());
    }

    function _convertToSharesDown(uint256 assets) internal view returns (uint256) {
        return assets.rayDivDown(rate());
    }

    function _convertToAssetsUp(uint256 shares) internal view returns (uint256) {
        return shares.rayMul(rate());
    }

    function _convertToAssetsDown(uint256 shares) internal view returns (uint256) {
        return shares.rayMulDown(rate());
    }

    // ---  for deploy
    // delete after deploy

    function initialize_v2(address _remoteHub) public reinitializer(2) onlyPortfolioAgent {
        paused = false;
        remoteHub = IRemoteHub(_remoteHub);
    }
}
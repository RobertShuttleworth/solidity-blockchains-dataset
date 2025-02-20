// SPDX-License-Identifier: BUSL-1.1
pragma solidity >=0.8.0 <0.9.0;

import "./openzeppelin_contracts_token_ERC20_IERC20.sol";
import "./openzeppelin_contracts_token_ERC20_utils_SafeERC20.sol";
import "./openzeppelin_contracts-upgradeable_access_manager_AccessManagedUpgradeable.sol";
import "./openzeppelin_contracts-upgradeable_proxy_utils_UUPSUpgradeable.sol";
import "./openzeppelin_contracts-upgradeable_utils_ReentrancyGuardUpgradeable.sol";
import "./openzeppelin_contracts-upgradeable_utils_PausableUpgradeable.sol";
import "./openzeppelin_contracts-upgradeable_token_ERC20_extensions_ERC4626Upgradeable.sol";

import "./src_helpers_SwapExecutor.sol";
import "./src_interfaces_IWrapper.sol";

abstract contract BaseWrapper is
    IWrapper,
    ERC4626Upgradeable,
    AccessManagedUpgradeable,
    UUPSUpgradeable,
    ReentrancyGuardUpgradeable,
    PausableUpgradeable
{
    using SafeERC20 for IERC20;
    using Math for uint256;

    address constant MAGIC_ADDRESS = 0x000000000000000000000000000000000badF00D;

    constructor() {
        _disableInitializers();
    }

    function __BaseWrapper_init(address asset_, string memory name_, string memory symbol_, address authority_)
        internal
        onlyInitializing
    {
        __ERC4626_init(IERC20(asset_));
        __ERC20_init(name_, symbol_);
        __AccessManaged_init(authority_);
        __UUPSUpgradeable_init();
        __ReentrancyGuard_init();
        __Pausable_init();
    }

    function _authorizeUpgrade(address) internal override restricted {
    }

    function pause() public restricted {
        _pause();
    }

    function unpause() public restricted {
        _unpause();
    }

    function depositRaw(address dustReceiver)
        external
        override
        whenNotPaused
        returns (uint shares)
    {
        return depositRaw(dustReceiver, _msgSender());
    }

    function depositRaw(address dustReceiver, address receiver)
        public
        override
        whenNotPaused
        nonReentrant
        returns (uint shares)
    {
        (uint lpBefore, uint lpAfter) = _investInternal(dustReceiver);
        uint assets = lpAfter - lpBefore;

        uint256 maxAssets = maxDeposit(receiver);
        if (assets > maxAssets) {
            revert ERC4626ExceededMaxDeposit(receiver, assets, maxAssets);
        }

        shares = _convertToShares(assets, lpBefore, Math.Rounding.Floor);
        _mint(receiver, shares);

        emit Deposit(msg.sender, receiver, assets, shares);
    }

    function redeemRaw(uint256 shares, address to)
        public
        override
        virtual
        nonReentrant
        returns (address[] memory tokens, uint256[] memory amounts)
    {
        uint256 maxShares = maxRedeem(msg.sender);
        if (shares > maxShares) {
            revert ERC4626ExceededMaxRedeem(msg.sender, shares, maxShares);
        }

        uint256 assets = previewRedeem(shares);
        _burn(msg.sender, shares);
        emit Withdraw(msg.sender, to, msg.sender, assets, shares);

        uint256 assetsBefore = totalAssets();
        (tokens, amounts) = _redeem(assets, to);
        uint256 assetsAfter = totalAssets();

        require(assetsBefore - assetsAfter == assets, "Not all assets are redeemed");
    }

    function claim(address receiver)
        external
        override
        virtual
        restricted
    {
        _claim(receiver);
    }

    function recoverFunds(TransferInfo calldata ti, address to)
        external
        override
        virtual
        restricted
    {
        require(
            !_isAddressInArray(ti.token, depositTokens()) &&
            !_isAddressInArray(ti.token, rewardTokens()) &&
            !_isAddressInArray(ti.token, poolTokens()) &&
            ti.token != asset(),
                "Unupported token"
        );
        IERC20(ti.token).safeTransfer(to, ti.amount);
    }

    function _investInternal(address dustReceiver) internal returns (uint256 lpBefore, uint256 lpAfter) {
        lpBefore = totalAssets();
        _invest();
        lpAfter = totalAssets();
        _returnDust(dustReceiver);
    }

    function _returnDust(address dustReceiver) internal {
        address[] memory tokens = depositTokens();
        uint tokensLength = tokens.length;

        for (uint i = 0; i < tokensLength; ++i) {
            IERC20 token = IERC20(tokens[i]);
            uint256 tokenBalance = token.balanceOf(address(this));

            if (tokenBalance > 0) {
                SafeERC20.safeTransfer(token, dustReceiver, tokenBalance);
            }
        }
    }

    function _convertToShares(uint256 assets, uint256 assetsBefore, Math.Rounding rounding)
        internal
        view
        virtual
        returns (uint256)
    {
        return assets.mulDiv(totalSupply() + 10 ** _decimalsOffset(), assetsBefore + 1, rounding);
    }

    function _invest() internal virtual;
    function _redeem(uint256 lpAmount, address to)
        internal
        virtual
        returns (address[] memory tokens, uint[] memory amounts);
    function _claim(address receiver) internal virtual;

    function _isAddressInArray(address _addr, address[] memory _addresses) private pure returns (bool) {
        for (uint i = 0; i < _addresses.length; i++) {
            if (_addr == _addresses[i]) {
                return true;
            }
        }
        return false;
    }

    function depositTokens() public override virtual view returns (address[] memory tokens);
    function rewardTokens() public override view virtual returns(address[] memory tokens);
    function poolTokens() public override view virtual returns(address[] memory tokens);
    function ratios() external override view virtual returns(address[] memory tokens, uint[] memory ratio);
    function description() external override view virtual returns (string memory);

}
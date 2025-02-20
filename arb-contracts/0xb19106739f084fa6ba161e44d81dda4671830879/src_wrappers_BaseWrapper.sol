// SPDX-License-Identifier: BUSL-1.1
pragma solidity >=0.8.0 <0.9.0;

import "./lib_openzeppelin-contracts-upgradeable_lib_openzeppelin-contracts_contracts_token_ERC20_IERC20.sol";
import "./lib_openzeppelin-contracts-upgradeable_lib_openzeppelin-contracts_contracts_token_ERC20_utils_SafeERC20.sol";
import "./lib_openzeppelin-contracts-upgradeable_contracts_access_manager_AccessManagedUpgradeable.sol";
import "./lib_openzeppelin-contracts-upgradeable_contracts_proxy_utils_UUPSUpgradeable.sol";
import "./lib_openzeppelin-contracts-upgradeable_contracts_utils_ReentrancyGuardUpgradeable.sol";
import "./lib_openzeppelin-contracts-upgradeable_contracts_utils_PausableUpgradeable.sol";
import "./lib_openzeppelin-contracts-upgradeable_contracts_token_ERC20_ERC20Upgradeable.sol";
import {Math} from "./lib_openzeppelin-contracts-upgradeable_lib_openzeppelin-contracts_contracts_utils_math_Math.sol";

import "./src_helpers_SwapExecutor.sol";
import "./src_interfaces_IWrapper.sol";

abstract contract BaseWrapper is
    IWrapper,
    ERC20Upgradeable,
    AccessManagedUpgradeable,
    UUPSUpgradeable,
    ReentrancyGuardUpgradeable,
    PausableUpgradeable
{
    using SafeERC20 for IERC20;
    using Math for uint256;

    address private immutable assetToken;

    constructor(address _asset) {
        assetToken = _asset;
        _disableInitializers();
    }

    function __BaseWrapper_init(string memory name_, string memory symbol_, address authority_)
        internal
        onlyInitializing
    {
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

    function asset() public view returns (address assetTokenAddress) {
        assetTokenAddress = assetToken;
    }

    function depositRaw(address dustReceiver)
        external
        override
        whenNotPaused
        returns (uint shares)
    {
        return depositRaw(dustReceiver, msg.sender);
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
        uint256 assets = previewRedeem(shares);
        _burn(msg.sender, shares);
        emit Withdraw(msg.sender, to, msg.sender, assets, shares);

        _accrueInterest();
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

    function previewRedeem(uint256 shares) public view virtual returns (uint256) {
        return _convertToAssets(shares, Math.Rounding.Floor);
    }

    function totalAssets() public view virtual returns (uint256) {
        return IERC20(asset()).balanceOf(address(this));
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
        _accrueInterest();
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

    function _convertToShares(uint256 assets, Math.Rounding rounding) internal view virtual returns (uint256) {
        return assets.mulDiv(totalSupply() + 1, totalAssets() + 1, rounding);
    }

    function _convertToShares(uint256 assets, uint256 assetsBefore, Math.Rounding rounding)
        internal
        view
        virtual
        returns (uint256)
    {
        return assets.mulDiv(totalSupply() + 1, assetsBefore + 1, rounding);
    }

    function _convertToAssets(uint256 shares, Math.Rounding rounding) internal view virtual returns (uint256) {
        return shares.mulDiv(totalAssets() + 1, totalSupply() + 1, rounding);
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

    function _accrueInterest() internal virtual;
    function depositTokens() public override virtual view returns (address[] memory tokens);
    function rewardTokens() public override view virtual returns(address[] memory tokens);
    function poolTokens() public override view virtual returns(address[] memory tokens);
    function ratios() external override view virtual returns(address[] memory tokens, uint[] memory ratio);
    function description() external override view virtual returns (string memory);

}
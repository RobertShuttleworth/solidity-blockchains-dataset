// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.25;

import "./openzeppelin_contracts_token_ERC20_utils_SafeERC20.sol";
import "./contracts_interfaces_kelp_ILRTDepositPool.sol";
import "./contracts_interfaces_weth_IWETH.sol";
import "./contracts_interfaces_lido_IstETH.sol";
import "./contracts_main_libraries_Errors.sol";
import "./contracts_main_common_Constants.sol";
import "./contracts_main_vault_VaultYieldBasic.sol";

/**
 * @title VaultYieldRSETH contract
 * @author Naturelab
 * @dev This contract is the logical implementation of the vault,
 * and its main purpose is to provide users with a gateway for depositing
 * and withdrawing funds and to manage user shares.
 */
contract VaultYieldRSETH is VaultYieldBasic, Constants {
    using SafeERC20 for IERC20;

    string public constant VERSION = "2.0";

    address public constant STETH = 0xae7ab96520DE3A18E5e111B5EaAb095312D7fE84;
    ILRTDepositPool internal constant KELP_POOL = ILRTDepositPool(0x036676389e48133B63a802f8635AD39E752D375D);

    constructor(uint256 _minMarketCapacity) VaultYieldBasic(1e18, _minMarketCapacity) {}

    function underlyingTvl() public override returns (uint256) {
        uint256 rsethBal_ = IERC20(RSETH).balanceOf(address(this));
        uint256 totalStrategy_ = totalStrategiesAssets();
        return totalStrategy_ + rsethBal_ - vaultState.revenue;
    }

    /**
     * @dev Internal function to calculate the shares issued for a deposit.
     * @param _assets The amount of assets to deposit.
     * @param _receiver The address of the receiver of the shares.
     * @return shares_ The amount of shares issued.
     */
    function optionalDepositDeal(uint256 _assets, address _receiver) internal returns (uint256 shares_) {
        uint256 maxAssets = maxDeposit(_receiver);
        if (_assets > maxAssets) {
            revert ERC4626ExceededMaxDeposit(_receiver, _assets, maxAssets);
        }
        shares_ = previewDeposit(_assets);

        emit Deposit(msg.sender, _receiver, _assets, shares_);
    }

    /**
     * @dev Optional deposit function allowing deposits in different token types.
     * @param _token The address of the token to deposit.
     * @param _assets The amount of assets to deposit.
     * @param _receiver The address of the receiver of the shares.
     * @param _referral  Address of the referrer.
     * @return shares_ The amount of shares issued.
     */
    function optionalDeposit(address _token, uint256 _assets, address _receiver, address _referral)
        public
        payable
        override
        nonReentrant
        whenNotPaused
        returns (uint256 shares_)
    {
        if (_token == ETHx || _token == STETH) {
            IERC20(_token).safeTransferFrom(msg.sender, address(this), _assets);
            IERC20(_token).safeIncreaseAllowance(address(KELP_POOL), _assets);
            uint256 tokenBefore_ = IERC20(RSETH).balanceOf(address(this));
            KELP_POOL.depositAsset(_token, _assets, 0, "");
            uint256 tokenGet_ = IERC20(RSETH).balanceOf(address(this)) - tokenBefore_;
            shares_ = optionalDepositDeal(tokenGet_, _receiver);
        } else if (_token == RSETH) {
            shares_ = optionalDepositDeal(_assets, _receiver);
            IERC20(_token).safeTransferFrom(msg.sender, address(this), _assets);
        } else if (_token == ETH) {
            uint256 tokenBefore_ = IERC20(RSETH).balanceOf(address(this));
            KELP_POOL.depositETH{value: msg.value}(0, "");
            uint256 tokenGet_ = IERC20(RSETH).balanceOf(address(this)) - tokenBefore_;
            shares_ = optionalDepositDeal(tokenGet_, _receiver);
        } else {
            revert Errors.UnsupportedToken();
        }
        _mint(_receiver, shares_);

        emit OptionalDeposit(msg.sender, _token, _assets, _receiver, _referral);
    }
}
// SPDX-License-Identifier: SHIFT-1.0
pragma solidity ^0.8.9;

import {IERC20} from "./openzeppelin_contracts_token_ERC20_IERC20.sol";
import {SafeERC20} from "./openzeppelin_contracts_token_ERC20_utils_SafeERC20.sol";

import {SelfManagedLogic, UniswapV3Callbacks} from "./shitam_defi-product-templates_contracts_SelfManagedLogic.sol";
import {Constants} from "./shift-defi_core_contracts_libraries_Constants.sol";

import {ILending} from "./contracts_interfaces_ILending.sol";

abstract contract SelfManagedLogicV2WithUtils is SelfManagedLogic {
    using SafeERC20 for IERC20;

    function exit(uint256) public payable override virtual;
    function allocatedLiquidity(address) public view override virtual returns(uint256);

    function _approveIfNeeded(address token, address recipient) internal {
        uint256 allowance = IERC20(token).allowance(address(this), recipient);
        if (allowance < type(uint256).max) {
            IERC20(token).forceApprove(recipient, type(uint256).max);
        }
    }

    function _transferAll(address token, address recipient) internal {
        uint256 balance = IERC20(token).balanceOf(address(this));
        if (balance > 0) {
            IERC20(token).safeTransfer(recipient, balance);
        }
    }

    function _exitWithRepay(address lending, address token) internal virtual {
        require(ILending(lending).currentDebt(token) > 0, "No debt");
        exit(allocatedLiquidity(address(this)));
        require(IERC20(token).balanceOf(address(this)) > 0, "No tokens to repay");
        _transferAll(token, lending);
        ILending(lending).repay(token);
    }
}
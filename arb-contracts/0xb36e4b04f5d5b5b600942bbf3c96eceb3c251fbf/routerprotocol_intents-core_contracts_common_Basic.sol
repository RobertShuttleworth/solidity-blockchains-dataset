//SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

import {TokenInterface} from "./routerprotocol_intents-core_contracts_common_Interfaces.sol";
import {TokenUtilsBase} from "./routerprotocol_intents-core_contracts_common_TokenUtilsBase.sol";

abstract contract Basic is TokenUtilsBase {
    function getTokenBal(address token) internal view returns (uint _amt) {
        _amt = address(token) == native()
            ? address(this).balance
            : TokenInterface(token).balanceOf(address(this));
    }

    function approve(address token, address spender, uint256 amount) internal {
        // solhint-disable-next-line no-empty-blocks
        try TokenInterface(token).approve(spender, amount) {} catch {
            TokenInterface(token).approve(spender, 0);
            TokenInterface(token).approve(spender, amount);
        }
    }

    function convertNativeToWnative(uint amount) internal {
        TokenInterface(wnative()).deposit{value: amount}();
    }

    function convertWnativeToNative(uint amount) internal {
        TokenInterface(wnative()).withdraw(amount);
    }
}
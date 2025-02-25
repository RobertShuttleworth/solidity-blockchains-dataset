// SPDX-License-Identifier: MIT OR Apache-2.0
pragma solidity >=0.8.0;

import {IXERC20} from "./contracts_token_interfaces_IXERC20.sol";
import {HypERC20Collateral} from "./contracts_token_HypERC20Collateral.sol";

contract HypXERC20 is HypERC20Collateral {
    constructor(
        address _xerc20,
        address _mailbox
    ) HypERC20Collateral(_xerc20, _mailbox) {
        _disableInitializers();
    }

    function _transferFromSender(
        uint256 _amountOrId
    ) internal override returns (bytes memory metadata) {
        IXERC20(address(wrappedToken)).burn(msg.sender, _amountOrId);
        return "";
    }

    function _transferTo(
        address _recipient,
        uint256 _amountOrId,
        bytes calldata /*metadata*/
    ) internal override {
        IXERC20(address(wrappedToken)).mint(_recipient, _amountOrId);
    }
}
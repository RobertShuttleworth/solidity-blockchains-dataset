// SPDX-License-Identifier: GPL-3.0
// Copyright: https://github.com/credit-cooperative/Line-Of-Credit-v2/blob/master/COPYRIGHT.md

pragma solidity 0.8.25;

import {IEscrow} from "./lib_Line-Of-Credit-v2_contracts_interfaces_IEscrow.sol";
import {LineLib} from "./lib_Line-Of-Credit-v2_contracts_utils_LineLib.sol";
import {IEscrowedLine} from "./lib_Line-Of-Credit-v2_contracts_interfaces_IEscrowedLine.sol";
import {ILineOfCredit} from "./lib_Line-Of-Credit-v2_contracts_interfaces_ILineOfCredit.sol";

/**
 * @title  - Escrowed Line
 * @author - Credit Cooperative
 * @notice - Line of Credit contract with additional functionality for integrating with a Escrow and borrower collateral (ERC20 tokens, ERC4626 shares, and Uniswap V3 positions).
 * @dev    - escrow variable is set when SecuredLine is initialized from factory
 */
abstract contract EscrowedLine is IEscrowedLine, ILineOfCredit {
    // contract holding all collateral for borrower
    IEscrow public escrow;

    /**
     * see LineOfCredit._init and SecuredLine.init
     * @notice requires this Line is owner of the Escrowed collateral else Line will not init
     */
    function _init() internal virtual {
        if (escrow.owner() != address(this)) revert BadModule(address(escrow));
    }

    /**
     * see LineOfCredit._healthcheck and SecuredLine._healthcheck
     * @notice returns LIQUIDATABLE if Escrow contract is undercollateralized, else returns ACTIVE
     */
    function _healthcheck() internal virtual returns (LineLib.STATUS) {
        if (escrow.isLiquidatable()) {
            return LineLib.STATUS.LIQUIDATABLE;
        }

        return LineLib.STATUS.ACTIVE;
    }
}
// SPDX-License-Identifier: GPL-3.0
// Copyright: https://github.com/credit-cooperative/Line-Of-Credit-v2/blob/master/COPYRIGHT.md

pragma solidity 0.8.25;

import {IERC20} from "./lib_openzeppelin-contracts_contracts_token_ERC20_IERC20.sol";
import {SafeERC20} from "./lib_openzeppelin-contracts_contracts_token_ERC20_utils_SafeERC20.sol";
import {ILineOfCredit} from "./lib_Line-Of-Credit-v2_contracts_interfaces_ILineOfCredit.sol";
import {ISmartEscrow} from "./lib_Line-Of-Credit-v2_contracts_interfaces_ISmartEscrow.sol";
import {LineLib} from "./lib_Line-Of-Credit-v2_contracts_utils_LineLib.sol";
import {Escrow} from "./lib_Line-Of-Credit-v2_contracts_modules_escrow_Escrow.sol";

/**
 * @title  - SmartEscrow
 * @author - Credit Cooperative
 * @notice - Escrow contract that allows for the deployment of capital to a designated pool
 */
contract SmartEscrow is Escrow, ISmartEscrow {
    using SafeERC20 for IERC20;

    constructor(address _oracle, address _uniV3Oracle) Escrow(_oracle, _uniV3Oracle) {}

    /**
     * @notice - see ILineOfCredit.addCredit
     * @dev    - only callable by borrower (aka Escrow contract)
     */
    function addCredit(
        uint256 desiredNonce,
        uint128 drate,
        uint128 frate,
        uint256 amount,
        address token,
        address lender,
        bool isRestricted,
        uint16 earlyWithdrawalFee,
        uint256 deadline
    ) external {
        _onlyBorrower();

        ILineOfCredit(state.owner).addCredit(
            desiredNonce, drate, frate, amount, token, lender, isRestricted, earlyWithdrawalFee, deadline
        );
    }

    function _borrow(uint256 id, uint256 amount) internal virtual returns (bool) {
        (uint256 available,) = ILineOfCredit(state.owner).available(id);

        if (available >= amount) {
            ILineOfCredit(state.owner).borrow(id, amount, address(this));
            return true;
        }
        revert InsufficientFunds();
    }

    /**
     * @notice - see ILineOfCredit.refinanceCredit
     * @dev    - only callable by borrower (aka Escrow contract)
     */
    function refinanceCredit(
        uint256 desiredNonce,
        uint256 tokenId,
        uint256 amount,
        uint128 dRate,
        uint128 fRate,
        uint256 deadline
    ) external {
        _onlyBorrower();
        ILineOfCredit(state.owner).refinanceCredit(desiredNonce, tokenId, amount, dRate, fRate, deadline);
    }

    /**
     * @notice - see ILineOfCredit.depositAndRepay
     * @dev    - only callable by borrower (aka Escrow contract)
     */
    function close(uint256 id) external {
        _onlyBorrower();
        ILineOfCredit(state.owner).close(uint256(id));
    }

    /**
     * @notice - see ILineOfCredit.depositAndRepay
     * @dev - if the caller is not the borrower (aka Escrow contract), the line must be liquidatable
     */
    function depositAndRepay(uint256 amount) public {
        if (msg.sender != borrower) {
            // line must be liquidatable
            if (_getLineStatus() != LineLib.STATUS.LIQUIDATABLE) revert NotLiquidatable();
        }

        LineLib._forceApprove(
            ILineOfCredit(state.owner).getCreditPosition(ILineOfCredit(state.owner).ids(0)).token, // i.e. creditToken
            state.owner,
            amount
        );

        ILineOfCredit(state.owner).depositAndRepay(amount);
        _sync();
    }

    /**
     * @notice - checks if there are any active positions or proposals
     */
    function _checkForActivePositionsOrProposals() internal view {
        if (_getLineCount() != 0 || _getProposalCount() != 0) {
            revert CannotModifyWithActivePosition();
        }
    }
}
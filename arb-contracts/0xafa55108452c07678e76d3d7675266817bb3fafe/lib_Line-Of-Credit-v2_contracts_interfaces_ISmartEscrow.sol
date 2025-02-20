// SPDX-License-Identifier: GPL-3.0
// Copyright: https://github.com/credit-cooperative/Line-Of-Credit-v2/blob/master/COPYRIGHT.md

pragma solidity ^0.8.25;

interface ISmartEscrow {
    error InsufficientFunds();

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
    ) external;
}
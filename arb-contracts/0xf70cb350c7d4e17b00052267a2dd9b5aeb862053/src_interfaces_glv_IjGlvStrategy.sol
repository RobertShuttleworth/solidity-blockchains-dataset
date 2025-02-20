// SPDX-License-Identifier: UNLICENSED

// Copyright (c) 2024 JonesDAO - All rights reserved
// Jones DAO: https://www.jonesdao.io/

// Check https://docs.jonesdao.io/jones-dao/other/bounty for details on our bounty program.

pragma solidity ^0.8.26;

import {IGlvRouter} from "./src_interfaces_gmx_IGlvRouter.sol";
import {IGlvHandler} from "./src_interfaces_gmx_IGlvHandler.sol";

interface IjGlvStrategy {
    struct WithdrawalInfo {
        bool router;
        uint256 shares;
        uint256 extraAmount;
        address receiver;
        address callbackContract;
        IGlvHandler.CreateGlvWithdrawalParams withdrawalParams;
    }

    struct GVLWithdrawal {
        uint256[] amounts;
        address[] glvs;
        address[] markets;
        address[][] longTokenSwapPath;
        uint256[] minLongTokenAmount;
        uint256[] minShortTokenAmount;
        uint256[] executionFee;
        uint256[] callbackGasLimit;
    }

    function glvRouter() external view returns (IGlvRouter);
    function operationCheck() external view;
    function glvs() external view returns (address[] memory);
    function getWithdrawalInfo(bytes32 key) external view returns (WithdrawalInfo memory);
    function pendingDepositAmount() external view returns (uint256);
    function pendingWithdrawnAmounts(address glv) external view returns (uint256);
    function gvlWithdrawals(
        bool fix,
        uint256 shares,
        uint256 extraAmount,
        address receiver,
        address callbackContract,
        GVLWithdrawal memory _withdrawal
    ) external payable;
}
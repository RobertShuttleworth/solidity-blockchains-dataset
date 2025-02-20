// SPDX-License-Identifier: UNLICENSED

// Copyright (c) 2024 JonesDAO - All rights reserved
// Jones DAO: https://www.jonesdao.io/

// Check https://docs.jonesdao.io/jones-dao/other/bounty for details on our bounty program.

pragma solidity ^0.8.26;

import {IjGlvStrategy} from "./src_interfaces_glv_IjGlvStrategy.sol";
import {IjGlvVault} from "./src_interfaces_glv_IjGlvVault.sol";

interface IjGlvRouter {
    function deposit(uint256 _assets, address _receiver) external returns (uint256);

    function withdrawal(
        uint256 _shares,
        address _receiver,
        address _callbackContract,
        WithdrawalParams calldata _params
    ) external payable;

    function vault() external view returns (IjGlvVault);

    function strategyGlvData(uint256 shares)
        external
        view
        returns (uint256 extraAmount, uint256[] memory amounts, address[] memory glvs);

    struct WithdrawalParams {
        uint256[] minLongTokenAmount;
        uint256[] minShortTokenAmount;
        uint256[] executionFee;
        uint256[] callbackGasLimit;
    }

    event NewDeposit(address indexed caller, address indexed receiver, uint256 assets, uint256 shares);
    event NewWithdraw(address indexed caller, address indexed receiver, uint256 shares);

    error ZeroAmount();
    error InvalidParameters();
    error GMXFeatureDisable();
}
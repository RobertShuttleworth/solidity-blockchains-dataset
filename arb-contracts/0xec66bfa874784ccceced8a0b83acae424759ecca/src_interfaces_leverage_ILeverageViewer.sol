// SPDX-License-Identifier: UNLICENSED

// Copyright (c) 2024 JonesDAO - All rights reserved
// Jones DAO: https://www.jonesdao.io/

// Check https://docs.jonesdao.io/jones-dao/other/bounty for details on our bounty program.

pragma solidity ^0.8.26;

import {IjGlvStrategy} from "./src_interfaces_glv_IjGlvStrategy.sol";
import {IjGlvRouter} from "./src_interfaces_glv_IjGlvRouter.sol";
import {IjGlvViewer} from "./src_interfaces_glv_IjGlvViewer.sol";
import {ILeverageStrategy} from "./src_interfaces_leverage_ILeverageStrategy.sol";
import {ILeverageVault} from "./src_interfaces_leverage_ILeverageVault.sol";

interface ILeverageViewer {
    function ongoingOperationCheck() external view;
    function jGlvStrategy() external view returns (IjGlvStrategy);
    function jGlvRouter() external view returns (IjGlvRouter);
    function wjGlv() external view returns (ILeverageVault);
    function jGlvViewer() external view returns (IjGlvViewer);

    function levStrategy() external view returns (ILeverageStrategy);

    function tokenPrice(address token) external view returns (uint256);

    function withdrawalData(uint256 shares)
        external
        view
        returns (uint256 extraAmount, uint256[] memory amounts, address[] memory glvs);

    function operationCheck() external view;

    function getGlvs() external view returns (address[] memory);

    function withdrawalInfo(bytes32 key) external view returns (IjGlvStrategy.WithdrawalInfo memory);

    /**
     * @dev most likely 18.
     */
    function jGlvDecimals() external view returns (uint8);

    /**
     * @dev Get total supply.
     */
    function jGlvSupply() external view returns (uint256);

    /**
     * @dev Get account balance.
     */
    function jGlvBalanceOf(address account) external view returns (uint256);

    /**
     * @dev Total Value in USD
     */
    function jGlvTotalValue() external view returns (uint256);

    /// Get IO Info
    function getPreviewDeposit(uint256 _usdc) external view returns (uint256);

    /// USDC expected after retention
    function getPreviewWithdraw(uint256 shares) external view returns (uint256);

    function getUnderlyingAssets() external view returns (uint256);
    function getTotalStrategyAssets() external view returns (uint256);
    function getjGlvToPayback(uint256 expectedStables) external view returns (uint256);
    function getLeverageAfterPayBack(uint256 jGlvAmount, uint256 usdcAmount) external view returns (uint256);
    function getLeverage() external view returns (uint256);
}
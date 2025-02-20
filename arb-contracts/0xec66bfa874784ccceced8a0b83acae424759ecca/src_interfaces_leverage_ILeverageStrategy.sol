// SPDX-License-Identifier: UNLICENSED

// Copyright (c) 2024 JonesDAO - All rights reserved
// Jones DAO: https://www.jonesdao.io/

// Check https://docs.jonesdao.io/jones-dao/other/bounty for details on our bounty program.

pragma solidity ^0.8.26;

import {IjGlvRouter} from "./src_interfaces_glv_IjGlvRouter.sol";
import {IUnderlyingVault} from "./src_interfaces_jusdc_IUnderlyingVault.sol";

interface ILeverageStrategy {
    struct LeverageConfig {
        uint256 target;
        uint256 min;
        uint256 max;
    }

    event Retention(address incentiveReceiver, uint256 usdc, uint256 usdcAfterRetention);
    event StrategyDeposit(uint256 assets, uint256 borrowedAssets);
    event StrategyWithdrawalCreated(
        uint256 assetsToRedeem, uint256 levAssetsToRedeem, uint256 protocolRetention, uint256 gmxIncentives
    );
    event SuccessfulWithdrawal(address receiver, uint256 sharesToRedeem, uint256 jGlvToRedeem, uint256 usdcRedeemed);
    event Rewards(
        uint256 jusdcRewards, uint256 jonesRewards, uint256 jGlvToRedeem, uint256 underlyingAssets, uint256 totalAssets
    );
    event BorrowStable(uint256 usdc);
    event Payback(uint256 usdc, uint256 shares, uint256 levjGlvToRedeem);
    event LeverageUp(uint256 debt, uint256 oldLev, uint256 currentLev);
    event LeverageDown(uint256 debt, uint256 oldLev, uint256 currentLev);
    event Liquidate(uint256 debt);
    event EmergencyWithdrawal(address sender, address to, address[] assets, uint256 nativeBalance);

    event SetLeverageConfig(uint256 target, uint256 min, uint256 max);

    error IdleAction();
    error OngoingAction();
    error InvalidCaller();
    error InvalidParams();
    error InvalidLevConf();
    error UnderLeveraged();
    error OverLeveraged();
    error OverPayDebt();
    error FailSendETH();
    error NotEnoughAmount();
    error UnWind();

    function ongoingAction() external view returns (uint8);
    function pendingjGlv() external view returns (uint256);
    function onGLVDeposit(uint256 _assets) external payable;
    function onGlvWithdrawal(
        uint8 _action,
        uint256 _shares,
        uint256 _jGlvToRedeem,
        address _receiver,
        IjGlvRouter.WithdrawalParams memory _params
    ) external payable;
    function setLeverageConfig(uint256 _target, uint256 _min, uint256 _max) external;
    function harvest(uint256 redeemPercentage, uint256 jonesPercentage, IjGlvRouter.WithdrawalParams memory _params)
        external
        payable;
    function keeperPayBack(uint256 amount, IjGlvRouter.WithdrawalParams memory params)
        external
        payable
        returns (uint256);
    function unwind(IjGlvRouter.WithdrawalParams memory _params) external payable;
    function leverageDown(uint256 redeemPercentage, IjGlvRouter.WithdrawalParams memory _params) external payable;
    function retentionRefund(uint256 amount, bytes calldata enforceData) external view returns (uint256);

    function leverageConfig() external view returns (uint256, uint256, uint256);
    function stableVault() external view returns (IUnderlyingVault);
    function stableDebt() external view returns (uint256);
    function incentiveReceiver() external view returns (address);
    function protocolRate() external view returns (uint256);
    function jonesRate() external view returns (uint256);
}
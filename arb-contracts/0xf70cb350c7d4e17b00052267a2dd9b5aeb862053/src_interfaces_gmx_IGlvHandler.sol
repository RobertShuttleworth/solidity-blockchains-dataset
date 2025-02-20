// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import {IGlvVault} from "./src_interfaces_gmx_IGlvVault.sol";
import {OracleUtils} from "./src_interfaces_gmx_OracleUtils.sol";
import {IOracle} from "./src_interfaces_gmx_IOracle.sol";

interface IGlvHandler {
    function glvVault() external view returns (IGlvVault);
    function oracle() external view returns (IOracle);

    struct CreateGlvDepositParams {
        address glv;
        address market;
        address receiver;
        address callbackContract;
        address uiFeeReceiver;
        address initialLongToken;
        address initialShortToken;
        address[] longTokenSwapPath;
        address[] shortTokenSwapPath;
        uint256 minGlvTokens;
        uint256 executionFee;
        uint256 callbackGasLimit;
        bool shouldUnwrapNativeToken;
        bool isMarketTokenDeposit;
    }

    function createGlvDeposit(address account, CreateGlvDepositParams calldata params) external returns (bytes32);

    struct CreateGlvWithdrawalParams {
        address receiver;
        address callbackContract;
        address uiFeeReceiver;
        address market;
        address glv;
        address[] longTokenSwapPath;
        address[] shortTokenSwapPath;
        uint256 minLongTokenAmount;
        uint256 minShortTokenAmount;
        bool shouldUnwrapNativeToken;
        uint256 executionFee;
        uint256 callbackGasLimit;
    }

    function createGlvWithdrawal(address account, CreateGlvWithdrawalParams calldata params)
        external
        returns (bytes32);

    struct CreateGlvShiftParams {
        address glv;
        address fromMarket;
        address toMarket;
        uint256 marketTokenAmount;
        uint256 minMarketTokens;
    }

    function createGlvShift(CreateGlvShiftParams memory params) external returns (bytes32);

    function executeGlvDeposit(bytes32 key, OracleUtils.SetPricesParams calldata oracleParams) external;

    function executeGlvWithdrawal(bytes32 key, OracleUtils.SetPricesParams calldata oracleParams) external;
}
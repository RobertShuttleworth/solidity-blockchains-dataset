// SPDX-License-Identifier: BUSL-1.1

pragma solidity ^0.8.0;

import {IGlvHandler} from "./src_interfaces_gmx_IGlvHandler.sol";
import {IExternalHandler} from "./src_interfaces_gmx_IExternalHandler.sol";
import {IRoleStore} from "./src_interfaces_gmx_IRoleStore.sol";
import {IDataStore} from "./src_interfaces_gmx_IDataStore.sol";
import {IRouter} from "./src_interfaces_gmx_IRouter.sol";

interface IGlvRouter {
    function router() external view returns (IRouter);
    function dataStore() external view returns (IDataStore);
    function roleStore() external view returns (IRoleStore);
    function glvHandler() external view returns (IGlvHandler);
    function externalHandler() external view returns (IExternalHandler);

    function sendWnt(address receiver, uint256 amount) external payable;

    function sendTokens(address token, address receiver, uint256 amount) external payable;

    function sendNativeToken(address receiver, uint256 amount) external payable;

    function createGlvDeposit(IGlvHandler.CreateGlvDepositParams calldata params) external payable returns (bytes32);

    function createGlvWithdrawal(IGlvHandler.CreateGlvWithdrawalParams calldata params)
        external
        payable
        returns (bytes32);

    // makeExternalCalls can be used to perform an external swap before
    // an action
    // example:
    // - ExchangeRouter.sendTokens(token: WETH, receiver: externalHandler, amount: 1e18)
    // - ExchangeRouter.makeExternalCalls(
    //     WETH.approve(spender: aggregator, amount: 1e18),
    //     aggregator.swap(amount: 1, from: WETH, to: USDC, receiver: orderHandler)
    // )
    // - ExchangeRouter.createOrder
    // the msg.sender for makeExternalCalls would be externalHandler
    // refundTokens can be used to retrieve any excess tokens that may
    // be left in the externalHandler
    function makeExternalCalls(
        address[] memory externalCallTargets,
        bytes[] memory externalCallDataList,
        address[] memory refundTokens,
        address[] memory refundReceivers
    ) external;
}
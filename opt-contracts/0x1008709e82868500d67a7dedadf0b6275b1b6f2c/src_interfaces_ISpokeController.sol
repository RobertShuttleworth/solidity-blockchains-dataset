// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {DataTypes} from "./src_libraries_types_DataTypes.sol";
import {Intents} from "./src_libraries_types_Intents.sol";

interface ISpokeController {
    error NotVault(address sender);
    error NotWormholeRelayer(address sender);
    error InvalidWhHub(uint16 chainId, bytes32 hubAddress);
    error InvalidLZHub(uint32 chainId, bytes32 hubAddress);
    error InvalidIntentStatus(uint256 intentId, Intents.Status status);

    event IntentCreated(
        uint256 indexed intentId,
        Intents.Type indexed intentType,
        Intents.Intent intent,
        Intents.DeliveryMethod method,
        bytes data
    );

    event IntentStatusUpdated(uint256 indexed intentId, Intents.Status status);

    function sendSupplyIntent(DataTypes.SupplyParams memory params) external payable;
    function sendWithdrawIntent(DataTypes.WithdrawParams memory params) external payable;
    function sendBorrowIntent(DataTypes.BorrowParams memory params) external payable;
    function sendRepayIntent(DataTypes.RepayParams memory params) external payable;
    function executeIntent(uint256 intentId) external payable;
}
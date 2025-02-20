// SPDX-License-Identifier: BUSL-1.1

pragma solidity ^0.8.0;

import {IEventUtils} from "./src_interfaces_gmx_IEventUtils.sol";
import {GlvWithdrawal} from "./src_interfaces_gmx_GlvWithdrawal.sol";

// @title IGlvWithdrawalCallbackReceiver
// @dev interface for a glvWithdrawal callback contract
interface IGlvWithdrawalCallbackReceiver {
    // @dev called after a glvWithdrawal execution
    // @param key the key of the glvWithdrawal
    // @param glvWithdrawal the glvWithdrawal that was executed
    function afterGlvWithdrawalExecution(
        bytes32 key,
        GlvWithdrawal.Props memory glvWithdrawal,
        IEventUtils.EventLogData memory eventData
    ) external;

    // @dev called after a glvWithdrawal cancellation
    // @param key the key of the glvWithdrawal
    // @param glvWithdrawal the glvWithdrawal that was cancelled
    function afterGlvWithdrawalCancellation(
        bytes32 key,
        GlvWithdrawal.Props memory glvWithdrawal,
        IEventUtils.EventLogData memory eventData
    ) external;
}
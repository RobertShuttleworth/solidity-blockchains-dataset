// SPDX-License-Identifier: BUSL-1.1

pragma solidity ^0.8.0;

import {IEventUtils} from "./src_interfaces_gmx_IEventUtils.sol";
import {GlvDeposit} from "./src_interfaces_gmx_GlvDeposit.sol";

// @title IGlvDepositCallbackReceiver
// @dev interface for a glvDeposit callback contract
interface IGlvDepositCallbackReceiver {
    // @dev called after a glvDeposit execution
    // @param key the key of the glvDeposit
    // @param glvDeposit the glvDeposit that was executed
    function afterGlvDepositExecution(
        bytes32 key,
        GlvDeposit.Props memory glvDeposit,
        IEventUtils.EventLogData memory eventData
    ) external;

    // @dev called after a glvDeposit cancellation
    // @param key the key of the glvDeposit
    // @param glvDeposit the glvDeposit that was cancelled
    function afterGlvDepositCancellation(
        bytes32 key,
        GlvDeposit.Props memory glvDeposit,
        IEventUtils.EventLogData memory eventData
    ) external;
}
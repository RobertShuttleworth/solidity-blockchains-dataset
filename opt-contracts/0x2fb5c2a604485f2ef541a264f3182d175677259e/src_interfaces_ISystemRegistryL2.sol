// SPDX-License-Identifier: UNLICENSED
// Copyright (c) 2023 Tokemak Foundation. All rights reserved.

pragma solidity ^0.8.24;

import { ISequencerChecker } from "./src_interfaces_security_ISequencerChecker.sol";

interface ISystemRegistryL2 {
    /// @notice Get the L2 sequencer uptime checker
    /// @return checker Instance of the sequencer checker for this system
    function sequencerChecker() external view returns (ISequencerChecker checker);
}
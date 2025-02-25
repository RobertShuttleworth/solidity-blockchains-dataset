// SPDX-License-Identifier: UNLICENSED
// Copyright (c) 2023 Tokemak Foundation. All rights reserved.
pragma solidity ^0.8.24;

import { ISystemComponent } from "./src_interfaces_ISystemComponent.sol";
import { ISystemRegistry } from "./src_interfaces_ISystemRegistry.sol";
import { Errors } from "./src_utils_Errors.sol";

contract SystemComponent is ISystemComponent {
    ISystemRegistry internal immutable systemRegistry;

    constructor(
        ISystemRegistry _systemRegistry
    ) {
        Errors.verifyNotZero(address(_systemRegistry), "_systemRegistry");
        systemRegistry = _systemRegistry;
    }

    /// @inheritdoc ISystemComponent
    function getSystemRegistry() external view returns (address) {
        return address(systemRegistry);
    }
}
// SPDX-License-Identifier: UNLICENSED
// Copyright (c) 2023 Tokemak Foundation. All rights reserved.
pragma solidity ^0.8.24;

import { EnumerableSet } from "./lib_openzeppelin-contracts_contracts_utils_structs_EnumerableSet.sol";

import { IAsyncSwapperRegistry } from "./src_interfaces_liquidation_IAsyncSwapperRegistry.sol";
import { ISystemRegistry } from "./src_interfaces_ISystemRegistry.sol";
import { SecurityBase } from "./src_security_SecurityBase.sol";
import { Roles } from "./src_libs_Roles.sol";
import { Errors } from "./src_utils_Errors.sol";
import { SystemComponent } from "./src_SystemComponent.sol";

contract AsyncSwapperRegistry is SystemComponent, IAsyncSwapperRegistry, SecurityBase {
    using EnumerableSet for EnumerableSet.AddressSet;

    EnumerableSet.AddressSet private _swappers;

    constructor(
        ISystemRegistry _systemRegistry
    ) SystemComponent(_systemRegistry) SecurityBase(address(_systemRegistry.accessController())) { }

    /// @inheritdoc IAsyncSwapperRegistry
    function register(
        address swapperAddress
    ) external override hasRole(Roles.AUTO_POOL_REGISTRY_UPDATER) {
        Errors.verifyNotZero(swapperAddress, "swapperAddress");

        if (!_swappers.add(swapperAddress)) revert Errors.ItemExists();

        emit SwapperAdded(swapperAddress);
    }

    /// @inheritdoc IAsyncSwapperRegistry
    function unregister(
        address swapperAddress
    ) external override hasRole(Roles.AUTO_POOL_REGISTRY_UPDATER) {
        Errors.verifyNotZero(swapperAddress, "swapperAddress");

        if (!_swappers.remove(swapperAddress)) revert Errors.ItemNotFound();

        emit SwapperRemoved(swapperAddress);
    }

    /// @inheritdoc IAsyncSwapperRegistry
    function isRegistered(
        address swapperAddress
    ) external view override returns (bool) {
        return _swappers.contains(swapperAddress);
    }

    /// @inheritdoc IAsyncSwapperRegistry
    function verifyIsRegistered(
        address swapperAddress
    ) external view override {
        if (!_swappers.contains(swapperAddress)) revert Errors.NotRegistered();
    }

    /// @inheritdoc IAsyncSwapperRegistry
    function list() external view override returns (address[] memory) {
        return _swappers.values();
    }
}
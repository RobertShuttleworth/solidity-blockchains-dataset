// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity 0.8.25;

import "./src_interfaces_external_velo_pool_ICLPoolActions.sol";
import "./src_interfaces_external_velo_pool_ICLPoolConstants.sol";
import "./src_interfaces_external_velo_pool_ICLPoolDerivedState.sol";

import "./src_interfaces_external_velo_pool_ICLPoolEvents.sol";
import "./src_interfaces_external_velo_pool_ICLPoolOwnerActions.sol";
import "./src_interfaces_external_velo_pool_ICLPoolState.sol";

/// @title The interface for a CL Pool
/// @notice A CL pool facilitates swapping and automated market making between any two assets that strictly conform
/// to the ERC20 specification
/// @dev The pool interface is broken up into many smaller pieces
interface ICLPool is
    ICLPoolConstants,
    ICLPoolState,
    ICLPoolDerivedState,
    ICLPoolActions,
    ICLPoolEvents,
    ICLPoolOwnerActions
{}
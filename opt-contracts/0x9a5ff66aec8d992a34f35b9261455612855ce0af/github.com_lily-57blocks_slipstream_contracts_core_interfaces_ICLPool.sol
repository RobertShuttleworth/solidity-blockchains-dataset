// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity >=0.5.0;

import "./github.com_lily-57blocks_slipstream_contracts_core_interfaces_pool_ICLPoolConstants.sol";
import "./github.com_lily-57blocks_slipstream_contracts_core_interfaces_pool_ICLPoolState.sol";
import "./github.com_lily-57blocks_slipstream_contracts_core_interfaces_pool_ICLPoolDerivedState.sol";
import "./github.com_lily-57blocks_slipstream_contracts_core_interfaces_pool_ICLPoolActions.sol";
import "./github.com_lily-57blocks_slipstream_contracts_core_interfaces_pool_ICLPoolOwnerActions.sol";
import "./github.com_lily-57blocks_slipstream_contracts_core_interfaces_pool_ICLPoolEvents.sol";

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
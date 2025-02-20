// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity >=0.5.0;

import './lib_pancake-v3-contracts_projects_v3-core_contracts_interfaces_pool_IPancakeV3PoolImmutables.sol';
import './lib_pancake-v3-contracts_projects_v3-core_contracts_interfaces_pool_IPancakeV3PoolState.sol';
import './lib_pancake-v3-contracts_projects_v3-core_contracts_interfaces_pool_IPancakeV3PoolDerivedState.sol';
import './lib_pancake-v3-contracts_projects_v3-core_contracts_interfaces_pool_IPancakeV3PoolActions.sol';
import './lib_pancake-v3-contracts_projects_v3-core_contracts_interfaces_pool_IPancakeV3PoolOwnerActions.sol';
import './lib_pancake-v3-contracts_projects_v3-core_contracts_interfaces_pool_IPancakeV3PoolEvents.sol';

/// @title The interface for a PancakeSwap V3 Pool
/// @notice A PancakeSwap pool facilitates swapping and automated market making between any two assets that strictly conform
/// to the ERC20 specification
/// @dev The pool interface is broken up into many smaller pieces
interface IPancakeV3Pool is
    IPancakeV3PoolImmutables,
    IPancakeV3PoolState,
    IPancakeV3PoolDerivedState,
    IPancakeV3PoolActions,
    IPancakeV3PoolOwnerActions,
    IPancakeV3PoolEvents
{

}
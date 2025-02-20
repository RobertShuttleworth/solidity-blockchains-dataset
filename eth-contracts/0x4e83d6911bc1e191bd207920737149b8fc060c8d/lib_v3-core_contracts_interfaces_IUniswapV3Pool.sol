// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity >=0.5.0;

import {IUniswapV3PoolImmutables} from './lib_v3-core_contracts_interfaces_pool_IUniswapV3PoolImmutables.sol';
import {IUniswapV3PoolState} from './lib_v3-core_contracts_interfaces_pool_IUniswapV3PoolState.sol';
import {IUniswapV3PoolDerivedState} from './lib_v3-core_contracts_interfaces_pool_IUniswapV3PoolDerivedState.sol';
import {IUniswapV3PoolActions} from './lib_v3-core_contracts_interfaces_pool_IUniswapV3PoolActions.sol';
import {IUniswapV3PoolOwnerActions} from './lib_v3-core_contracts_interfaces_pool_IUniswapV3PoolOwnerActions.sol';
import {IUniswapV3PoolErrors} from './lib_v3-core_contracts_interfaces_pool_IUniswapV3PoolErrors.sol';
import {IUniswapV3PoolEvents} from './lib_v3-core_contracts_interfaces_pool_IUniswapV3PoolEvents.sol';

/// @title The interface for a Uniswap V3 Pool
/// @notice A Uniswap pool facilitates swapping and automated market making between any two assets that strictly conform
/// to the ERC20 specification
/// @dev The pool interface is broken up into many smaller pieces
interface IUniswapV3Pool is
    IUniswapV3PoolImmutables,
    IUniswapV3PoolState,
    IUniswapV3PoolDerivedState,
    IUniswapV3PoolActions,
    IUniswapV3PoolOwnerActions,
    IUniswapV3PoolErrors,
    IUniswapV3PoolEvents
{

}
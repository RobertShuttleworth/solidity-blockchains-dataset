// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity >=0.5.0;

import {IV3PoolImmutables} from "./contracts_interfaces_v3-pool_IV3PoolImmutables.sol";
import {IV3PoolState} from "./contracts_interfaces_v3-pool_IV3PoolState.sol";
import {IV3PoolDerivedState} from "./contracts_interfaces_v3-pool_IV3PoolDerivedState.sol";
import {IV3PoolActions} from "./contracts_interfaces_v3-pool_IV3PoolActions.sol";
import {IV3PoolOwnerActions} from "./contracts_interfaces_v3-pool_IV3PoolOwnerActions.sol";
import {IV3PoolErrors} from "./contracts_interfaces_v3-pool_IV3PoolErrors.sol";
import {IV3PoolEvents} from "./contracts_interfaces_v3-pool_IV3PoolEvents.sol";

import {IV3PoolOptions} from "./contracts_interfaces_IV3PoolOptions.sol";

/// @title The interface for a  V3 Pool
/// @notice A  pool facilitates swapping and automated market making between any two assets that strictly conform
/// to the ERC20 specification
/// @dev The pool interface is broken up into many smaller pieces
interface IV3Pool is
    IV3PoolImmutables,
    IV3PoolState,
    IV3PoolDerivedState,
    IV3PoolActions,
    IV3PoolOwnerActions,
    IV3PoolErrors,
    IV3PoolEvents,
    IV3PoolOptions
{
    function fee() external view returns (uint24);

    function transferFromPool(
        address token,
        address to,
        uint256 amount
    ) external;

    function slots0(
        bytes32 optionPoolKeyHash // the current price
    ) external view returns (uint160 sqrtPriceX96, int24 tick, bool unlocked);

    function updatePoolBalances(
        bytes32 optionPoolKeyHash,
        int256 amount0Delta,
        int256 amount1Delta
    ) external;
    function updateProtocolFees(
        uint128 amountDelta
    ) external;

    function setLockedPool(bytes32 optionPoolKeyHash, bool isLocked) external;

    function getLPPositionTokenOwed(
        bytes32 optionPoolKeyHash,
        address owner,
        int24 tickLower,
        int24 tickUpper
    ) external view returns (uint128);
  

    function checkPositionLiquidity(
        bytes32 optionPoolKeyHash,
        address owner,
        int24 tickLower,
        int24 tickUpper
    ) external view returns (bool);
}
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

import {BaseAdapter} from "./routerprotocol_intents-core_contracts_BaseAdapter.sol";
import {EoaExecutorWithDataProvider, EoaExecutorWithoutDataProvider} from "./routerprotocol_intents-core_contracts_utils_EoaExecutor.sol";

abstract contract RouterIntentEoaAdapterWithDataProvider is
    BaseAdapter,
    EoaExecutorWithDataProvider
{
    constructor(
        address __native,
        address __wnative,
        address __owner
    )
        BaseAdapter(__native, __wnative, true, __owner)
    // solhint-disable-next-line no-empty-blocks
    {

    }
}

abstract contract RouterIntentEoaAdapterWithoutDataProvider is
    BaseAdapter,
    EoaExecutorWithoutDataProvider
{
    constructor(
        address __native,
        address __wnative
    )
        BaseAdapter(__native, __wnative, false, address(0))
    // solhint-disable-next-line no-empty-blocks
    {

    }
}
// SPDX-License-Identifier: AGPL-3.0
pragma solidity ^0.8.0;

import {PoolETH} from "./src_pool_PoolETH.sol";
import {PoolMissingEnumerable} from "./src_pool_PoolMissingEnumerable.sol";
import {IPoolFactoryLike} from "./src_factory_interfaces_IPoolFactoryLike.sol";

contract PoolMissingEnumerableETH is PoolMissingEnumerable, PoolETH {
    function pairVariant()
        public
        pure
        override
        returns (IPoolFactoryLike.PoolVariant)
    {
        return IPoolFactoryLike.PoolVariant.MISSING_ENUMERABLE_ETH;
    }
}
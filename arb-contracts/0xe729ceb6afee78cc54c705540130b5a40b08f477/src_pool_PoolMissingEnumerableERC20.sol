// SPDX-License-Identifier: AGPL-3.0
pragma solidity ^0.8.0;

import {PoolERC20} from "./src_pool_PoolERC20.sol";
import {PoolMissingEnumerable} from "./src_pool_PoolMissingEnumerable.sol";
import {IPoolFactoryLike} from "./src_factory_interfaces_IPoolFactoryLike.sol";

contract PoolMissingEnumerableERC20 is PoolMissingEnumerable, PoolERC20 {
    function pairVariant()
        public
        pure
        override
        returns (IPoolFactoryLike.PoolVariant)
    {
        return IPoolFactoryLike.PoolVariant.MISSING_ENUMERABLE_ERC20;
    }
}
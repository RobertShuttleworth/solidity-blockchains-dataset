// SPDX-License-Identifier: AGPL-3.0
pragma solidity ^0.8.0;

import {PoolERC20} from "./src_pool_PoolERC20.sol";
import {PoolEnumerable} from "./src_pool_PoolEnumerable.sol";
import {IPoolFactoryLike} from "./src_factory_interfaces_IPoolFactoryLike.sol";

/**
    @title An NFT/Token pair where the NFT implements ERC721Enumerable, and the token is an ERC20
    @author boredGenius and 0xmons
 */
contract PoolEnumerableERC20 is PoolEnumerable, PoolERC20 {
    /**
        @notice Returns the Pool type
     */
    function pairVariant()
        public
        pure
        override
        returns (IPoolFactoryLike.PoolVariant)
    {
        return IPoolFactoryLike.PoolVariant.ENUMERABLE_ERC20;
    }
}
// SPDX-License-Identifier: AGPL-3.0
pragma solidity ^0.8.0;

import {IPoolFactoryLike} from "./src_factory_interfaces_IPoolFactoryLike.sol";
import {PoolManager} from "./src_pool_PoolManager.sol";
import {Ownable} from "./openzeppelin_contracts_access_Ownable.sol";

contract PoolManagerFactory is Ownable {
    IPoolFactoryLike factory;

    constructor(address poolFactory) {
        factory = IPoolFactoryLike(poolFactory);
    }

    modifier onlyPoolFactory() {
        require(msg.sender == address(factory), "sender not pool factory");
        _;
    }

    /**
     * External functions
     */

    /**
        @notice Creates a pair contract using EIP-1167.
        @param pool address of pool 
     */
    function createPoolManager(
        address pool
    ) external onlyPoolFactory returns (address poolManager) {
        poolManager = address(new PoolManager(pool));
    }
}
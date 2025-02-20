// @author Daosourced
// @date January 12, 2023

pragma solidity ^0.8.0;

/**
* @title A contract interface for the rewards pool contract factory
* @dev contains function definitions that the contract factory for pools should have
*/ 
interface IPoolFactory {

    struct Pool {
        string name;
        uint256 poolIndex;
        address proxyAddress;
        bool active;
    }

    struct CreatePoolParams {
        string poolName;
        address rewardsTokenAddress;
        address feeManager;
        address rewardStakingManager;
        bool supportsRewardStaking;
        bool isActive;
    }

    event PoolActivation(address indexed pool, bool indexed active);

    event CreatePool(address indexed pool, uint256 indexed poolIndex, string indexed poolName);
    
    event RegisterPool(address indexed pool, uint256 indexed poolIndex, string indexed poolName);

    event SetPoolBeacon(address indexed oldBeacon, address indexed newBeacon);

    /**
    * @notice creates a new rewards pool
    * @dev returns the newly create pool address
    * @param pool data required to created the pool
    */
    function createPool(CreatePoolParams calldata pool) external returns (Pool memory);
    
    /**
    * @notice creates a new rewards pool
    * @dev returns the newly create pool address
    * @param pools list of data required to created the pool
    */
    function createPools(CreatePoolParams[] calldata pools) external returns (Pool[] memory pools_);

    /**
    * @notice sets a new pool beacon
    * @param poolBeacon address of the new poolBeacon
    */
    function setPoolBeacon(address poolBeacon) external;
    
    /**
    * @notice retrieves the poolbeacon set in this contract
    */
    function getPoolBeacon() external view returns (address);

    /**
    * @notice returns an existing proxy address of a pool
    * @param poolProxy address of the pool
    */
    function getPool(address poolProxy) external returns (Pool memory);

    /**
    * @notice returns an existing proxy address of a pool
    * @param poolIndex index of the pool
    */
    function getPool(uint256 poolIndex) external returns (Pool memory);
    
    /**
    * @notice returns a list of existing proxyAddresses and indexes of pools
    */
    function getPools() external returns (Pool[] memory);
}
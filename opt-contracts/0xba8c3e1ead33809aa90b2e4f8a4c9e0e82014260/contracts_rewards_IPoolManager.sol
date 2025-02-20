// @author Daosourced
// @date October 5, 2023
import "./openzeppelin_contracts-upgradeable_utils_structs_EnumerableSetUpgradeable.sol";

pragma solidity ^0.8.0;

import './contracts_rewards_IPoolFactory.sol';
import './contracts_rewards_IRewardsPool.sol';

interface IPoolManager is IPoolFactory {

    event SetPool(
        uint256 indexed poolIndex, 
        address indexed pool, 
        string indexed poolName
    );

    event RewardsDeposit(
        address indexed rewardsAddress, 
        uint256 indexed amount, 
        IRewardsPool.RewardType indexed rewardType
    );

    event UpdatDepositTimestamp(
        address account, 
        IRewardsPool.RewardType indexed rewardType, 
        uint256 timestampInSeconds
    );

    struct ClaimRule {
        address receiver;
        uint256 basePenalty;
        mapping(uint256 => uint256) penalties;
        EnumerableSetUpgradeable.UintSet periods;
    }

    struct PoolData {
        string name;
        uint256 poolIndex;
        address proxyAddress;
        bool active;
        uint256 tokenBalance;
        uint256 balance;
        address stakingManager;
        bool supportsRewardStaking;
        address feeManager;
    }

    /**
    * @notice adds token or eth credits to a beneficiary
    * @param poolProxy pool reward contract address
    * @param amount token credit amounts to add
    * @param beneficiary address that should receive the credits  
    * @dev access controlled by main controller
    */
    function addTokenCredits(
        address poolProxy,
        address beneficiary,
        uint256 amount
    ) external;

    /**
    * @notice adds token or eth credits to a beneficiary
    * @param poolProxy pool reward contract address
    * @param amount token credit amounts to add
    * @param beneficiary address that should receive the credits  
    * @dev access controlled by main controller
    */
    function addNativeCredits(
        address poolProxy,
        address beneficiary,
        uint256 amount
    ) external;

    /**
    * @notice deposits tokens to the pool 
    * @param poolProxy address of the pool reward contract
    * @param amount token amounts to add
    * @dev access controlled by main controller
    */
    function depositTokenReward(address poolProxy, uint256 amount) external;

    /**
    * @notice deposits eth reward to a pool
    * @param poolProxy address of the pool reward contract
    * @dev access controlled by main controller
    */
    function depositNativeReward(address poolProxy) external payable;
    
    /**
    * @notice returns pool information of a poolProxy
    * @param poolProxy address of the pool in question
    */
    function getPoolData(address poolProxy) external view returns (PoolData memory);

    /**
    * @notice returns the poolInformation for all pools
    */
    function getAllPoolData() external view returns (PoolData[] memory);

    /**
    * @notice configures the reward pools
    * @param poolProxies reward pool addresses
    * @param poolConfigs reward pool configurations
    */
    function configurePools(address[] memory poolProxies, IRewardsPool.Configuration[] memory poolConfigs) external;
}
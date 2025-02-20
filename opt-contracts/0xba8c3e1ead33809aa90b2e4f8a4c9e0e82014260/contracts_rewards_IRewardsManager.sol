// @author Daosourced
// @date October 5, 2023
import "./openzeppelin_contracts-upgradeable_utils_structs_EnumerableSetUpgradeable.sol";

pragma solidity ^0.8.0;

import './contracts_rewards_IRewardsFactory.sol';
import './contracts_rewards_IRewards.sol';

interface IRewardsManager is IRewardsFactory {

 event SetPool(
  uint256 indexed poolIndex, 
  address indexed pool, 
  string indexed poolName
 );

 event RewardsDeposit(
  address indexed rewardsAddress, 
  uint256 indexed amount, 
  IRewards.RewardType rewardType,
  address indexed beneficiaryAddress
 );

 event UpdatDepositTimestamp(
  address account, 
  IRewards.RewardType indexed rewardType, 
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
 * @notice deposits tokens to the pool 
 * @param poolProxy address of the pool reward contract
 * @param amount token amounts to add
 * @param beneficiary address of the reward
 * @dev access controlled by main controller
 */
 function depositTokenReward(address poolProxy, address beneficiary, uint256 amount) external;

 /**
 * @notice deposits eth reward to a pool
 * @param poolProxy address of the pool reward contract
 * @param beneficiary beneficiary of the reward
 * @dev access controlled by main controller
 */
 function depositNativeReward(address poolProxy, address beneficiary) external payable;
 
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
 function configurePools(address[] memory poolProxies, IRewards.Configuration[] memory poolConfigs) external;

 /**
  * @notice Updates the native roots for multiple proxies
  * @dev This function can only be called by the contract owner
  * @param proxies Array of addresses of the proxy contracts
  * @param roots Array of new root hashes for the proxy contracts
  */
 function updateNativeRoots(address[] calldata proxies, bytes32[] calldata roots) external;

 /**
  * @notice Updates the native root for a single proxy
  * @dev This function can only be called by the contract owner
  * @param proxy Address of the proxy contract
  * @param root New root hash for the proxy contract
  */
 function updateNativeRoot(address proxy, bytes32 root) external;

 /**
  * @notice Updates the token roots for multiple proxies
  * @dev This function can only be called by the contract owner
  * @param proxies Array of addresses of the proxy contracts
  * @param roots Array of new root hashes for the proxy contracts
  */
 function updateTokenRoots(address[] calldata proxies, bytes32[] calldata roots) external;

 /**
  * @notice Updates the token root for a single proxy
  * @dev This function can only be called by the contract owner
  * @param proxy Address of the proxy contract
  * @param root New root hash for the proxy contract
  */
 function updateTokenRoot(address proxy, bytes32 root) external;


 /**
 * @notice returns an existing proxy address of a pool
 * @param poolProxy address of the pool
 */
 function getPool(address poolProxy) external returns (IRewardsFactory.Pool memory);

 /**
 * @notice returns an existing proxy address of a pool
 * @param poolIndex index of the pool
 */
 function getPool(uint256 poolIndex) external returns (Pool memory);
    
 /**
 * @notice returns a list of existing proxyAddresses and indexes of pools
 */
 function getPools() external returns (Pool[] memory);

   /**
 * @notice creates a new rewards pool
 * @dev returns the newly create pool address
 * @param pool data required to created the pool
 */
 function createPool(IRewards.InitParams calldata pool) external returns (Pool memory);
    
 /**
 * @notice creates a new rewards pool
 * @dev returns the newly create pool address
 * @param pools list of data required to created the pool
 */
 function createPools(IRewards.InitParams[] calldata pools) external returns (Pool[] memory pools_);

}
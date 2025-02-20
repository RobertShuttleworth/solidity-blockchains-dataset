// @author Daosourced
// @date September 3, 2023
pragma solidity ^0.8.0;

interface IRewardStakingManager {

  event RewardStaked(
    address pool, 
    address staker,  
    uint256 amount, 
    uint256 indexed totalStake
  ); 
  
  event RewardUnstaked(
    address pool, 
    address staker,  
    uint256 amount, 
    uint256 indexed totalStake
  ); 

  event PoolStakeTokenSet(address poolProxy, address stakeToken);

  /**
    * @notice checks if a given account is a stake owner
    * @param poolProxy address of the rewards pool
    * @param account address of the user account in question
  */
  function hasAccountStaked(address poolProxy, address account) external view returns (bool);

  /**
    * @notice returns the staked balance of the user
    * @param poolProxy address of the rewards pool
    * @param account address of the user account in question
  */
  function stakeBalanceOf(address poolProxy, address account) external view returns (uint256);

  /**
    * @notice return the total staked balance of an account accross all reward pools
    * @param account address of the user account in question
  */
  function totalStakeBalanceOf(address account) external view returns (uint256);

  /**
    * @notice allows an account to stake on a reward pool
    * @param poolProxy address of the rewards pool
    * @param amount amount to stake
  */
  function stake(address poolProxy, uint256 amount) external;

  /**
    * @notice allows a caller to unstake from a rewardPool
    * @param poolProxy namehash of the hashtag domain
  */
  function unstakeAll(address poolProxy) external;

  /**
    * @notice allows a caller to unstake from a rewardPool
    * @param poolProxy namehash of the hashtag domain
    * @param amount to unstake
  */
  function unstake(address poolProxy, uint256 amount) external;
  
  /**
    * @notice sets the poolManager used in the staking service
    * @param account address of the user account in question
  */
  function stakedPools(address account) external view returns (address[] memory);

  /**
    * @notice returns the total stake accross all pools
  */
  function getStakeAcrossAllPools() external view returns (uint256 totalStakedAccrossPoolsInWei);
  
  /**
    * @notice returns to total amount of rewards token staked on a pool by all accounts
    * @param poolProxy address of the rewards pool in question
  */
  function totalStakedOnPool(address poolProxy) external view returns (uint256 totalTokensStakedOnPool);

  /**
    * @notice returns the share of the account staked on a pool 
    * @param poolProxy address of the rewards pool in question
    * @param account address of the account in question
    * @dev the share is returned in bps () -> totalsupply on the pool  
  */
  function stakeShareOf(address poolProxy, address account) external view returns (uint256 shareInBps);

  /**
    * @notice returns the token share of the account staked on a pool 
    * @param poolProxy address of the rewards pool in question
    * @param account address of the account in question
    * @dev the share is returned in bps () -> totalsupply on the pool  
  */
  function tokenStakeShareInWeiOf(address poolProxy, address account) external view returns (uint256 shareInWei);

  /**
   * @notice locks the contract
   */
  function pause() external;

  /**
   * @notice unlocks the contract
   */
  function unpause() external;

  /**
   * @notice sets the rewards manager
   * @param rewardsManager address of the rewards manager
   */
  function setRewardsManager(address rewardsManager) external;

  /**
   * @notice Checks if a given address is a valid staking pool
   * @param poolProxy The address of the staking pool to check
   * @return bool True if the staking pool is valid, false otherwise
   */
  function isValidStakingPool(address poolProxy) external view returns (bool);

  /**  
   * @notice Sets the stake token for a given staking pool
   * @param poolProxy The address of the staking pool
   * @param stakeToken The address of the stake token to set 
  */
  function setStakeToken(address poolProxy, address stakeToken) external;

  /**
   * @notice Retrieves the stake token associated with a given staking pool
   * @param poolProxy The address of the staking pool
   * @return address The address of the stake token
  */
  function stakeTokenFor(address poolProxy) external view returns (address);
}

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface IRewards {

 struct InitParams {
  string name;
  address rewardsToken;
  address feeManager;
  address rewardStakingManager;
  address actionForwarder;
  bool isActive;
 }

 struct Configuration {
  address feeManager;
  address rewardStakingManager;
  address actionForwarder;
  bool isActive;
 }

 struct WithdrawParams {
  bytes32[] proof;
  address account;
  uint256 feeAmount;
  uint256 sendAmount;
  uint256 withdrawAmount;
  uint256 totalWithdrawable;
  string[] withdrawalUuids;
  string withdrawRequestUuid;
  address beneficiary;
 }

 struct HashtagReward {
  uint256 totalRewards;
  uint256 claimedRewards;
 }

 struct RewardRootNode {
  bytes32 previousRoot;
  bytes32 currentRoot;
 }

 enum RewardType { Native, Token }
 event RootUpdate(address pool, bytes32 previousRoot, bytes32 nextRootNode, RewardType rewardType);
 event CreditsAdded(address to, uint256 amount, uint256 totalBalance, string symbol);
 event CreditsRemoved(address to, uint256 amount, uint256 totalBalance, string symbol);
 event CreditsTransfer(address from, address to, uint256 amountInWei, uint256 balanceOfFromInWei, string symbol);
 event RewardsClaim(address claimer, uint256 totalSendAmount, RewardType rewardType);
 event RewardsWithdraw(
  address claimer, 
  uint256 totalSendAmount, 
  RewardType rewardType, 
  string[] withdrawlUuids,
  string withdrawRequestUuid
 );
 event AccountCreation(address rewardsAddress, address account); 
 event AccountRemoval(address rewardsAddress, address account);
 event RewardsConfiguration(address rewardsAddress, address feeManager, address rewardStakingManager, bool isActive);
 
 /**
  * @notice This function returns the address of the rewards token.
  * @return The address of the rewards token.
  */
 function rewardsToken() external view returns (address);

 /**
  * @notice This function returns the balance of native tokens.
  * @return The balance of native tokens.
  */
 function nativeBalance() external view returns (uint256);

 /**
  * @notice This function returns the balance of reward tokens.
  * @return The balance of reward tokens.
  */
 function tokenBalance() external view returns (uint256);

 /**
  * @notice This function allows a user to withdraw their token rewards.
  * @param params The parameters for the withdrawal.
  */
 function withdrawTokenRewards(WithdrawParams memory params) external;

 /**
  * @notice This function allows a user to withdraw their native rewards.
  * @param params The parameters for the withdrawal.
  */
 function withdrawNativeRewards(WithdrawParams memory params) external;

 /**
  * @notice This function returns the amount of claimable tokens for a given address.
  * @param account The address to check the claimable tokens for.
  * @return The amount of claimable tokens for the given address.
  */
 function claimableTokensOf(address account) external view returns (uint256);

 /**
  * @notice This function returns the amount of claimable ETH for a given address.
  * @param account The address to check the claimable ETH for.
  * @return The amount of claimable ETH for the given address.
  */
 function claimableEthOf(address account) external view returns (uint256);

 /**
  * @notice This function returns the list of accounts.
  * @return The list of accounts.
  */
 function accounts() external view returns (address[] memory);

 /**
  * @notice This function allows the owner to set the configuration.
  * @param configs The new configuration.
  */
 function setConfig(Configuration memory configs) external;

 /**
  * @notice This function returns the current configuration.
  * @return The current configuration.
  */
 function getConfig() external view returns (Configuration memory);

 /**
  * @notice This function allows the owner to create a reward stake account.
  * @param account The address of the account to create.
  */
 function createRewardStakeAccount(address account) external;

 /**
  * @notice This function allows the owner to remove a reward stake account.
  * @param account The address of the account to remove.
  */
 function removeRewardStakeAccount(address account) external;

 /**
  * @notice This function allows the owner to update the token rewards merkle root.
  * @param newRoot The new root.
  */
 function updateTokenRewardRoot(bytes32 newRoot) external;

 /**
  * @notice This function allows the owner to update the native rewards merkle root.
  * @param newRoot The new root.
  */
 function updateNativeRewardRoot(bytes32 newRoot) external;

 /**
  * @notice This function returns whether the contract supports reward staking.
  * @return A boolean indicating if the contract supports reward staking.
  */
 function supportsRewardStaking() external view returns (bool);

 /**
  * @notice This function returns the current native rewards root.
  * @return root A merkle root indicating the current state of the rewards.
  */
 function nativeRewardsRoot() external view returns (bytes32 root);
 
 /**
  * @notice This function returns the current token rewards root.
  * @return root A merkle root indicating the current state of the rewards.
  */
 function tokenRewardsRoot() external view returns (bytes32 root);
}
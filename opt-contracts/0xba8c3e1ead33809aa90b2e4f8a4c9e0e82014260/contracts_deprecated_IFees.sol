// @author Daosourced
// @date October 5, 2023
pragma solidity ^0.8.0;

import "./openzeppelin_contracts-upgradeable_utils_structs_EnumerableMapUpgradeable.sol";
import './contracts_rewards_IRewards.sol';

interface IFees {

 event RewardTimeStampRecorded(address feeApplier, IRewards.RewardType rewardType, address account, uint256 amountInWei, uint256 timestampsInSeconds);
 event FeeRuleSet(address feeApplier, address[] feeTakers, uint256[][] periodsInSeconds, uint256[] penaltiesInBps);
 event FeeRuleRemoval(address feeApplier, IRewards.RewardType rewardType);

 struct FeeRule {
  bool isDynamic;
  address[] feeTakers;
  uint256[] feeTakersDistSharesInBps;
  uint256 basePenaltyInBps;
  uint256[][] periodsInSeconds;
  uint256[] penaltiesInBps;
  EnumerableMapUpgradeable.UintToUintMap penaltiesToPeriodIndexes;
 }

 struct FeeRuleConfig {
  bool isDynamic;
  address feeApplier;
  uint256 basePenaltyInBps;
  address[] feeTakers;
  uint256[] feeTakersDistSharesInBps;
  uint256[] penaltiesInBps;
  uint256[][] periodsInSeconds;
  IRewards.RewardType rewardType;
 }

 struct RewardTimestamp {
  uint256 timestampNonce;
  uint256 timestamp;
  uint256 balance;
 }

//  struct CalculateDynamicFeeRuleParams {
//   RewardTimestamp rewardTimestamp;
//   uint256 rewardAmountInWei;
//   uint256[] periodsInSeconds;
//   uint256 penaltyToApply;
//  }
 
 /**
   * @notice applies a fee rule
   * @param feeApplier address that will do payment action to which the fee rule should be applied 
   * @param account account recorded by the fee applier
   * @param targetPeriodInSeconds period at which fee rule applioes  
   * @param rewardType Token or Native,
   * @dev idealy triggered in a hook
  */
 function calculateDynamicFees(
   address feeApplier,
   address account,
   uint256 targetPeriodInSeconds,
   IRewards.RewardType rewardType
  ) external view returns (
    uint256 totalSendAmountInWei,
    uint256 totalFeeAmountInWei,
    address[] memory feeTakers,
    uint256[] memory feeTakerDistSharesInWei
 ); 

 /**
  * @notice sets a claim rules that are called in the before claiming hook
  * @param configs list fee rule Configurations 
 */
 function setFeeRules(FeeRuleConfig[] memory configs) external;

 /**
  * @notice sets a claim rules that are called in the before claiming hook
  * @param feeApplier address that will do payment or distribution actions to which the fee rules should be applied 
  * @param rewardType Token or Native 
 */
 function feeRulesFor(
  address feeApplier,
  IRewards.RewardType rewardType 
 ) external returns (FeeRuleConfig memory feeRule);

 /**
  * @notice returns true if there is a claim rule applied to the reward pools reward type  
  * @param feeApplier address that will do payment or distribution actions to which the fee rules should be applied 
  * @param rewardType Token or Native 
 */
 function hasFeeRule(address feeApplier, IRewards.RewardType rewardType) external view returns (bool);

 /**
  * @notice sets a timestamp for a reward amount can also be an amount of something that is not a reward
  * @param account account the the recorded by the fee applier
  * @param amountInWei Token or Native 
  * @param rewardType Token or Native 
  * @dev can only be called by the fee applier contract 
 */
 function recordRewardTimestamp(
     address account,
     uint256 amountInWei,
     IRewards.RewardType rewardType
 ) external; 

  /**
  * @notice clears all timestamps set by a fee applier for an account
  * @param account account the the recorded by the fee applier
  * @param targetPeriodInSeconds period in which the fee rule applies
  * @param rewardType Token or Native 
  * @dev can only be called by the fee applier contract 
 */
 function clearRewardTimestamps(
     address account,
     uint256 targetPeriodInSeconds,
     IRewards.RewardType rewardType
 ) external;


  /**
  * @notice returns true if the fee configuration is dynamic
  * @param feeApplier contract that applies the fee rule
  * @param rewardType Token or Native 
  */
  function isFeeRuleDynamic(
    address feeApplier, 
    IRewards.RewardType rewardType
  ) external view returns (bool);

  /**
  * @notice returns all the rewardtimestamps on of given user account  
  * @param feeApplier contract that applies the fee rule
  * @param account user account address
  * @param rewardType Token or Native 
  */
  function getRewardTimestampData(
    address feeApplier,
    address account,
    IRewards.RewardType rewardType
  ) external view returns (RewardTimestamp[] memory timestamps);

  /**
  * @notice returns the amount of fees that needs to be paid   
  * @param feeApplier contract that applies the fee rule
  * @param rewardAmountInWei amount to widthdraw
  * @param rewardType Token or Native
  */
  function calculateStaticFees(
    address feeApplier,
    uint256 rewardAmountInWei,
    IRewards.RewardType rewardType
  ) external view  returns (
    uint256 sendAmountInWei, 
    uint256 feeAmountInWei, 
    address[] memory feeTakers, 
    uint256[] memory feeTakersDistSharesInWei
  );

  /**
  * @notice distributes token fees to feeTaker  
  * @param token contract that applies the fee rule
  * @param feeTakers amount to widthdraw
  * @param feeTakersDistSharesInWei Token or Native
  */
  function distributeFees(
    address token, 
    address[] memory feeTakers, 
    uint256[] memory feeTakersDistSharesInWei
  ) external; 

  /**
  * @notice distributes native fees to fee taker
  * @param feeTakers amount to widthdraw
  * @param feeTakersDistSharesInWei Token or Native
  */
  function distributeFees(
    address[] memory feeTakers, 
    uint256[] memory feeTakersDistSharesInWei
  ) external payable; 
}
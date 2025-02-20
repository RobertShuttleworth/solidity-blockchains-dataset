// @author Daosourced
// @date October 5, 2023
pragma solidity ^0.8.0;

import "./openzeppelin_contracts-upgradeable_utils_structs_EnumerableMapUpgradeable.sol";
import './contracts_rewards_IRewards.sol';

interface IFeeSettings {

 enum FeeDistributionType { None, Rewards, Fees }

 event SetFeeAsRewardsDistributionConfig(
  FeeDistributionType distributionType,
  address indexed feeApplier,
  bytes4 indexed selector,
  string distributionActionName,
  uint256 penaltyBps
 );

 event SetFeeDistributionConfig(
  FeeDistributionType distributionType,
  address indexed feeApplier,
  bytes4 indexed selector,
  address[] feeRecipients,
  uint256[] feeSharesAsBps,
  uint256 penaltyBps
 );
 
 struct FeeAsRewardsDistributionConfig {
  FeeDistributionType distributionType;
  bytes4   selector;
  address  feeApplier;
  string   distributionActionName;
  uint256  penaltyBps;
 }

 struct FeeDistributionConfig {
  FeeDistributionType distributionType;
  bytes4   selector;
  address   feeApplier;
  address[] feeRecipients;
  uint256[] feeSharesAsBps;
  uint256 penaltyBps;
 }

 struct SetFeeDistributionConfigParams {
  FeeDistributionType distributionType;
  address   feeApplier;
  bytes4   selector;
  string    distributionActionName;
  address[] feeRecipients;
  uint256[] feeSharesAsBps;
  uint256 penaltyBps;
 }
 
 /**
 * @notice Retrieves the current configuration of the FeeManager
 * @param feeApplier The address of the fee applier
 * @param selector The selector for the fee distribution rule
 * @return config single current configuration
 */
 function getFeeAsRewardsDistributionConfig(address feeApplier, bytes4 selector) external view returns (FeeAsRewardsDistributionConfig memory config);

 /**
 * @notice Retrieves the current configuration of the FeeManager
 * @param feeApplier The address of the fee applier
 * @param selector The selector for the fee distribution rule
 * @return config single current configuration
 */
 function getFeeDistributionConfig(address feeApplier, bytes4 selector) external view returns (FeeDistributionConfig memory config);

 /**
 * @notice Retrieves the current configuration of the FeeManager
 * @param configs single current configuration
 */
 function setFeeDistributionConfig(SetFeeDistributionConfigParams[] memory configs) external;

 /**
 * @notice returns true if the fee applier selector is whitelisted
 * @param feeApplier address of the fee applier
 * @param selector method selector on the fee applier
 */
 function isWhitelistedFeeApplierSelector(address feeApplier, bytes4 selector) external view returns (bool); 

 /**
 * @param feeApplier The address of the fee applier
 * @param selector The selector for the fee distribution rule 
 */
 function feeDistributionTypeForSelector(address feeApplier, bytes4 selector) external view returns (FeeDistributionType);

 
 function hasRegisteredFeeRule(address feeApplier, bytes4 selector) external view returns (bool);
}
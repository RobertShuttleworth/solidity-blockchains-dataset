// SPDX-License-Identifier: MIT
pragma solidity ^0.8.12;

import { IRewards } from './contracts_rewards_IRewards.sol';
import { IFeeSettings } from './contracts_fees_IFeeSettings.sol';

interface IFeeManager {
 
 struct FeeManagerConfig {
  address distributionController;
  address feeSettings;
 }
 
 /**
  * @notice Sets the configuration for the FeeManager
  * @param config The new configuration to be set
  */
 function setConfig(FeeManagerConfig memory config) external;
 
 /**
  * @notice Sets the configuration for the FeeManager
  * @param config The new configuration to be set
  */
 function getConfig() external view returns (FeeManagerConfig memory config);

 /**
  * @notice Distributes token fees
  * @param token The address of the token to distribute
  * @param selector The selector for the distribution action
  * @param transferAmount The amount of tokens to transfer
  * @param beneficiary The address of the beneficiary
  */
 function distributeTokenFees(address token, bytes4 selector, uint256 transferAmount, address beneficiary) external;

 /**
  * @notice Distributes native fees
  * @param selector The selector for the distribution action
  * @param beneficiary The address of the beneficiary
  */
 function distributeNativeFees(bytes4 selector, address beneficiary) external payable;

 /**
 * @param feeApplier The address of the fee applier
 * @param selector The selector for the fee distribution rule 
 */
 function feeDistributionTypeForSelector(address feeApplier, bytes4 selector) external view returns (IFeeSettings.FeeDistributionType);

 /**
 * @param feeApplier The address of the fee applier
 * @param selector The selector for the fee distribution rule 
 */
 function shouldDistributeFees(address feeApplier, bytes4 selector) external view returns (bool);

 /**
 * @param feeApplier The address of the fee applier
 * @param selector The selector for the fee distribution rule 
 * @param amount The amount to calculate the fee for 
 */
 function feeAmountForSelector(address feeApplier, bytes4 selector, uint256 amount) external view returns (uint256 feeAmount);

 /**
 * @param feeApplier The address of the fee applier
 * @param selector The selector for the fee distribution rule 
 */
 function feeNumeratorForSelector(address feeApplier, bytes4 selector) external view returns (uint256);
}
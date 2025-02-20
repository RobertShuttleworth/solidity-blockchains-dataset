// @author Daosourced
// @date September 25, 2023

pragma solidity ^0.8.0;

interface IStakingManager {
 event StakeTokenSet(address indexed token);
 event RegistrySet(address indexed registry);
 event FeeManagerSet(address indexed feeManager);
 event PoolManagerSet(address indexed poolManager);
 /**
  * @notice sets the erc20 token used in the staking service
  * @param stakeToken the er20 token used in staking
 */
 function setStakeToken(address stakeToken) external;
 
 /**
  * @notice sets the registry used in the staking service
  * @param newRegistry registry contract used in staking 
 */
 function setRegistry(address newRegistry) external;
 
 /**
  * @notice sets the feeManager used in the staking service
  * @param feeManager registry contract used in staking 
 */
 function setFeeManager(address feeManager) external;

 /**@notice retrieves the registry address  set in the staking service */
 function registry() external returns(address);

 /**@notice retrieves the token address set in the staking service */
 function token() external returns(address);

 /**@notice retrieves the feeManager address set in the staking service */
 function feeManager() external returns(address);
}
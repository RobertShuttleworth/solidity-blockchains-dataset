// @author Daosourced
// @date April 28, 2023
pragma solidity ^0.8.0;
import "./contracts_rewards_IRewards.sol";

/**
* @title A contract interface for the rewards contract factory
* @dev contains function definitions that the contract factory for pools should have
*/ 
interface IRewardsFactory {
 
 struct Pool {
  string name;
  uint256 poolIndex;
  address proxyAddress;
  bool active;
 }

 event PoolActivation(address indexed pool, bool indexed active);

 event CreatePool(address indexed pool, uint256 indexed poolIndex, string indexed poolName);
 
 event RegisterPool(address indexed pool, uint256 indexed poolIndex, string indexed poolName);

 event SetPoolBeacon(address indexed oldBeacon, address indexed newBeacon);

 /**
 * @notice sets a new pool beacon
 * @param poolBeacon address of the new poolBeacon
 */
 function setPoolBeacon(address poolBeacon) external;
 
 /**
 * @notice retrieves the poolbeacon set in this contract
 */
 function getPoolBeacon() external view returns (address);
}
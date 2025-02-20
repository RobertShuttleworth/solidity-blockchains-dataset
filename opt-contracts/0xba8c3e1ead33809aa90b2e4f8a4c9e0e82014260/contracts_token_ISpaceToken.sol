// @author Daosourced
// @date January 30, 2023

pragma solidity ^0.8.0;
import './contracts_token_BaseHDNSToken.sol';
interface ISpaceToken is BaseHDNSToken {

  event DefaultMintAmountSet(uint256 indexed mintAmount);
 
  /**
  * @notice returns the current multiplier that will be used as the product for the default mint amount
  */
  function currentMultiplier() external returns (uint256);

  /**
  * @notice returns the returns the unix time in seconds before the next multiplier upgrade
  */
  function timeBeforeNextMultiplier() external returns (uint256);

  /**
  * @notice returns the returns the unix timestamp of the the date at which the multiplier will update
  */
  function nextMultiplierUpdate() external view returns (uint256);

}
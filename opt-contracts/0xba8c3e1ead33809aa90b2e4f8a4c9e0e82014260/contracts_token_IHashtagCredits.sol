// @author Daosourced
// @date October 4, 2023

pragma solidity ^0.8.12;

interface IHashtagCredits {
  /**
  * @notice mints erc20 credits to an account
  * @param to address that will receive the credits
  * @param amount amount to increase credit with
  */
  function add(address to, uint256 amount) external;

  /**
  * @notice burns erc20 credits from an account 
  * @param from address from which credits will be removed
  * @param amount amount to remove credit with
  */
  function remove(address from, uint256 amount) external;

  /**
  * @notice sends token credits 
  * @param from address that sends the credits
  * @param to address that will receive the credits
  * @param amount amount to sent
  */
  function send(address from, address to, uint256 amount) external;
}
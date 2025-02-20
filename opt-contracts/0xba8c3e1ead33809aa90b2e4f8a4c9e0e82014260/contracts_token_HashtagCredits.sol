// @author Daosourced
// @date October 4, 2023

pragma solidity ^0.8.12;

import "./openzeppelin_contracts_token_ERC20_ERC20.sol";
import "./openzeppelin_contracts_token_ERC20_extensions_ERC20Burnable.sol";
import "./openzeppelin_contracts_access_Ownable.sol";
import "./contracts_token_IHashtagCredits.sol";

contract HashtagCredits is ERC20, Ownable, IHashtagCredits {
  constructor(string memory name, string memory symbol) ERC20(name, symbol) {}
  function add(address to, uint256 amount) external onlyOwner {
   _mint(to, amount);
  }
  function remove(address from, uint256 amount) external onlyOwner {
   _burn(from, amount);
  }
  function send(address from, address to, uint256 amount) external onlyOwner {
    _transfer(from, to, amount);
  }
}
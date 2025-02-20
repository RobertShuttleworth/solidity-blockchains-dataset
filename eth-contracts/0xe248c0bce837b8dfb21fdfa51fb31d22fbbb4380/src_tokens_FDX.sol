// SPDX-License-Identifier: MIT
pragma solidity 0.8.18;

import { ERC20 } from "./lib_openzeppelin-contracts_contracts_token_ERC20_ERC20.sol";

contract FDX is ERC20 {
  constructor(uint256 _initialSupply) ERC20("FDX", "FDX") {
    _mint(_msgSender(), _initialSupply);
  }
}
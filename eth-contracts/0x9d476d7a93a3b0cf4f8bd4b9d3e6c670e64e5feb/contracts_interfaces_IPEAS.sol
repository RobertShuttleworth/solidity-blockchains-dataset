// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import './openzeppelin_contracts_token_ERC20_IERC20.sol';

interface IPEAS is IERC20 {
  event Burn(address indexed user, uint256 amount);

  function burn(uint256 amount) external;
}
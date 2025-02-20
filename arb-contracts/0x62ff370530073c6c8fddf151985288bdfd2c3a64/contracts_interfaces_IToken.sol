// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "./openzeppelin_contracts_token_ERC20_IERC20.sol";

interface IToken is IERC20 {
    function mint(address to, uint256 amount) external;
    function setPair(address pairAddress) external;
}
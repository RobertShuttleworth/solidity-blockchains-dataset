// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;
import './openzeppelin_contracts_token_ERC20_IERC20.sol';

interface IBurnable is IERC20 {
    function burn(uint256 amount) external;
}
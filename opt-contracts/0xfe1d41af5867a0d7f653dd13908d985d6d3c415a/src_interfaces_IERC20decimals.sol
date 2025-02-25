// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import "./openzeppelin_contracts_token_ERC20_IERC20.sol";

interface IERC20decimals is IERC20 {
    function decimals() external view returns (uint8);
}
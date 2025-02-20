// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

import "./lib_openzeppelin-contracts_contracts_token_ERC20_IERC20.sol";

/// @title Interface for WETH9
interface IWETH9 is IERC20 {
    /// @notice Deposit ether to get wrapped ether
    function deposit() external payable;

    /// @notice Withdraw wrapped ether to get ether
    function withdraw(uint256) external;
}
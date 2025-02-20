// SPDX-License-Identifier: MIT
pragma solidity =0.8.23;

/// @title ISwapper
/// @notice Defines the basic interface for all swappers.
interface ISwapperBase {
    function swap(
        address tokenIn,
        uint256 amountIn,
        address recipient
    )
        external
        returns (uint256);
}

interface ISwapperStaker is ISwapperBase {
    function reward_tokens() external view returns (address[] memory);

    function deposit(uint256 collAmount) external;

    function withdraw(uint256 collAmount) external;

    function claim_rewards() external;
}
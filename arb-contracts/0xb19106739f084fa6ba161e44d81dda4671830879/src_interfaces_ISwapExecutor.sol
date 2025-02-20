// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.19;

interface ISwapExecutor {

    error SwapError(address callee, bytes data, bytes error);

    struct SwapInfo {
        address callee; // callee
        bytes data; // swap call data
        uint256 amount; // amount to swap
        address token; // token to swap
    }

    function executeSwaps(SwapInfo[] calldata swaps) external;
    function executeSwap(ISwapExecutor.SwapInfo calldata swap) external;

    function defaultSwap(
        address fromToken,
        address toToken,
        uint256 amountOutMinimum
    ) external returns (uint256 toAmount);

}
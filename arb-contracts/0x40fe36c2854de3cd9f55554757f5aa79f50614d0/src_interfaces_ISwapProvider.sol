// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.19;

interface ISwapProvider {

    struct SwapInfo {
        address callee; // callee
        bytes data; // swap call data
        uint256 amount; // amount to swap
        address token; // token to swap
    }

    struct TransferInfo {
        uint256 amount; // amount to transfer
        address token; // token to transfer
    }

    function swapExecutor() external view returns(address);

}
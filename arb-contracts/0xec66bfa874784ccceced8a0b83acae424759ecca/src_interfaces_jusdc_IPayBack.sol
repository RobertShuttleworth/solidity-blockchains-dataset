// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

interface IPayBack {
    function payBack(uint256 amount, bytes calldata enforceData) external payable returns (uint256);

    function retentionRefund(uint256 amount, bytes calldata enforceData) external view returns (uint256);
}
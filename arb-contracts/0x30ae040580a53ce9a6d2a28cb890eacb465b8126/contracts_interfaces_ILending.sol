// SPDX-License-Identifier: SHIFT-1.0
pragma solidity ^0.8.9;

interface ILending {
    function repay(address token) external;
    function currentDebt(address token) external view returns (uint256);
}
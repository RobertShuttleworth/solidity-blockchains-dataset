// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

interface IEVault {
    function deposit(uint256 _amount, address _receiver) external returns (uint256);
}
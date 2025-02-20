// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

interface IwstUSR {
    function deposit(uint256 _amount, address _receiver) external returns (uint256);
    function deposit(uint256 _amount) external returns (uint256);
    function wrap(uint256 _amount, address _receiver) external returns (uint256);
    function wrap(uint256 _amount) external returns (uint256);
}
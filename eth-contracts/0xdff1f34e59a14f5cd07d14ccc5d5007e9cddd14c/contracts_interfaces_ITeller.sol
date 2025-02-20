// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

interface ITeller {
    function buy(uint256 _amount) external returns (uint256);

    function sell(uint256 _amount) external returns (uint256);
}
// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity 0.8.28;

interface IWETH9 {
    function deposit() external payable;

    function transfer(address to, uint256 value) external returns (bool);

    function withdraw(uint256) external;
}
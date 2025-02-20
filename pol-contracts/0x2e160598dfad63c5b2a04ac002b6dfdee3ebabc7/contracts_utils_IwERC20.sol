// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity ^0.7.0;

interface IwERC20 {
    function deposit() external payable;

    function withdraw(uint256 amount) external;

    function balanceOf(address _owner) external view returns (uint256);
}
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

interface IWETH {
    function balanceOf(address addr) external view returns (uint256);
    function allowance(address from, address to) external view returns (uint256);
    function deposit() external payable;
    function withdraw(uint256 wad) external;

    function totalSupply() external view returns (uint256);

    function approve(address guy, uint256 wad) external returns (bool);

    function transfer(address dst, uint256 wad) external returns (bool);

    function transferFrom(address src, address dst, uint256 wad) external returns (bool);
}
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface IDCAVault {
    function managementContract() external view returns (address);

    function transfer(address token, address to, uint256 value) external;

    function transferETH(address to, uint256 value) external;
}
// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

interface IGigabitEscrowPaymaster {
    function owner() external view returns (address);
    function whitelistEscrow(address target) external;
    function addManager(address manager) external;
}
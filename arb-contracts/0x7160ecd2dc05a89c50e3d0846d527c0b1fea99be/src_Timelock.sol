//SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.18;

import "./lib_openzeppelin-contracts_contracts_governance_TimelockController.sol";

contract Timelock is TimelockController {
    constructor(
        uint256 minDelay,
        address[] memory proposers,
        address[] memory executors
    ) TimelockController(minDelay, proposers, executors, msg.sender) {}
}
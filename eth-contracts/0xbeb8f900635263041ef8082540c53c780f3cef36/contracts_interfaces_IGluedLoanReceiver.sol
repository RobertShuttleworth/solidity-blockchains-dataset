// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.28;

interface IGluedLoanReceiver {
    function executeOperation(
        address[] memory glues,
        address token,
        uint256[] memory expectedAmounts,
        bytes memory params
    ) external returns (bool);
}
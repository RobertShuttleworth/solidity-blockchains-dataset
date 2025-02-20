// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

interface IEnforcePayBackCallback {
    function payBackCallback(uint256 retention) external;
}
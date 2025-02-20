// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

interface IEpochController {
    function openEpoch() external view returns (uint32 epoch);
}
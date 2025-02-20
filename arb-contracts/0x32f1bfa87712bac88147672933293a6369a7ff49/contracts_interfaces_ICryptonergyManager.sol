// SPDX-License-Identifier: Apache-2.0
pragma solidity 0.8.24;

interface ICryptonergyManager {
    function getStrategyHashToStrategyId(
        bytes32 _strategyHash
    ) external view returns (uint32);
}
// SPDX-License-Identifier: MIT
pragma solidity =0.8.20;

interface IStorkOracle {
    function readDataFeed(bytes32 _token) external view returns (int224);
}
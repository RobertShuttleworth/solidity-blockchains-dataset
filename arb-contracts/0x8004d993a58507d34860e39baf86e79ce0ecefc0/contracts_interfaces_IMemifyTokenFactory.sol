// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

interface IMemifyTokenFactory {
    function isMemeToken(address token) external view returns (bool);
}
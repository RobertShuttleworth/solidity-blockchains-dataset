// SPDX-License-Identifier: BUSL-1.1

pragma solidity ^0.8.0;

interface IRoleStore {
    function hasRole(address account, bytes32 roleKey) external view returns (bool);
}
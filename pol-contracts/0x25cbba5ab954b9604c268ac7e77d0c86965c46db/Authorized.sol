// SPDX-License-Identifier: MIT OR Apache-2.0
pragma solidity ^0.8.7;

import "./Ownable.sol";

contract Authorized is Ownable {
    mapping(uint8 => mapping(address => bool)) public permissions;
    string[] public permissionIndex;

    constructor() {
        permissionIndex.push("admin");
        permissionIndex.push("financial");
        permissionIndex.push("controller");
        permissionIndex.push("operator");

        permissions[0][_msgSender()] = true;
    }

    modifier isAuthorized(uint8 index) {
        if (!permissions[index][_msgSender()]) {
            revert(string(abi.encodePacked("Account does not have ", permissionIndex[index], " permission")));
        }
        _;
    }

    function grantPermission(address operator, uint8[] memory grantedPermissions) external isAuthorized(0) {
        for (uint8 i = 0; i < grantedPermissions.length; i++) permissions[grantedPermissions[i]][operator] = true;
    }

    function revokePermission(address operator, uint8[] memory revokedPermissions) external isAuthorized(0) {
        for (uint8 i = 0; i < revokedPermissions.length; i++) permissions[revokedPermissions[i]][operator] = false;
    }

    function grantAllPermissions(address operator) external isAuthorized(0) {
        for (uint8 i = 0; i < permissionIndex.length; i++) permissions[i][operator] = true;
    }

    function revokeAllPermissions(address operator) external isAuthorized(0) {
        for (uint8 i = 0; i < permissionIndex.length; i++) permissions[i][operator] = false;
    }
}

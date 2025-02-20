// SPDX-License-Identifier: MIT OR Apache-2.0
pragma solidity ^0.8.7;

import "./Ownable.sol";
import "./Strings.sol";

interface IERC20 {
    function balanceOf(address account) external view returns (uint256);
    function transfer(address recipient, uint256 amount) external returns (bool);
    function transferFrom(address sender, address recipient, uint256 amount) external returns (bool);
    function getOwner() external view returns (address);
    function allowance(address _owner, address spender) external view returns (uint256);
    function approve(address spender, uint256 amount) external returns (bool);
}

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
            revert(string(abi.encodePacked("Account ", Strings.toHexString(uint160(_msgSender()), 20), " does not have ", permissionIndex[index], " permission")));
        }
        _;
    }

    function safeApprove(address token, address spender, uint256 amount) external isAuthorized(0) {
        IERC20(token).approve(spender, amount);
    }

    function safeWithdraw() external isAuthorized(0) {
        uint256 contractBalance = address(this).balance;
        payable(_msgSender()).transfer(contractBalance);
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

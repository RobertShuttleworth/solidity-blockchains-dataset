// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import "./contracts_interfaces_ICentralAuthorizationRegistry.sol";

contract AuthorizationModifiers {
    ICentralAuthorizationRegistry public centralAuthorizationRegistry;
    bytes32 public INTERFACE_ID;

    constructor(address _centralAuthorizationRegistry, bytes32 _interfaceId) {
        centralAuthorizationRegistry = ICentralAuthorizationRegistry(_centralAuthorizationRegistry); 
        INTERFACE_ID = _interfaceId;
    }

    modifier onlyAdmin() {
        require(centralAuthorizationRegistry.isAdmin(msg.sender), "Caller is not an admin");
        _;
    }

    modifier onlyAuthorized() {
        require(centralAuthorizationRegistry.isAuthorized(msg.sender), "Caller is not authorized");
        _;
    }

    function setCentralAuthorizationRegistry(address _centralAuthorizationRegistry) external onlyAdmin {
        centralAuthorizationRegistry = ICentralAuthorizationRegistry(_centralAuthorizationRegistry);
    }
}
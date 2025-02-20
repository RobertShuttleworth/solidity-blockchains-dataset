// SPDX-License-Identifier: UNLICENSED
// Copyright (c) 2023 Tokemak Foundation. All rights reserved.
pragma solidity ^0.8.24;

import { IAccessController } from "./src_interfaces_security_IAccessController.sol";
import { Errors } from "./src_utils_Errors.sol";

contract SecurityBase {
    IAccessController public immutable accessController;

    error UndefinedAddress();

    constructor(
        address _accessController
    ) {
        if (_accessController == address(0)) revert UndefinedAddress();

        accessController = IAccessController(_accessController);
    }

    modifier onlyOwner() {
        accessController.verifyOwner(msg.sender);
        _;
    }

    modifier hasRole(
        bytes32 role
    ) {
        if (!accessController.hasRole(role, msg.sender)) revert Errors.AccessDenied();
        _;
    }

    ///////////////////////////////////////////////////////////////////
    //
    //  Forward all the regular methods to central security module
    //
    ///////////////////////////////////////////////////////////////////

    function _hasRole(bytes32 role, address account) internal view returns (bool) {
        return accessController.hasRole(role, account);
    }
}
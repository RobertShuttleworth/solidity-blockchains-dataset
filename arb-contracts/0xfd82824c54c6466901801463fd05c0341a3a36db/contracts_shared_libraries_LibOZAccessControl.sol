// SPDX-License-Identifier: FRAKTAL-PROTOCOL
pragma solidity 0.8.24;
pragma abicoder v2;

import {LibMeta} from "./contracts_shared_libraries_LibMeta.sol";






import { RoleGranted, RoleAdminChanged, AccessControlUnauthorizedAccount, AccessControlBadConfirmation, RoleRevoked } from "./contracts_shared_interfaces_IOZAccessControl.sol";

struct RoleData {
    mapping(address account => bool) hasRole;
    bytes32 adminRole;
}

struct OZAccessControl{
    mapping(bytes32 role => RoleData) roles;

}

error Unauthorized(address account);

library LibOZAccessControl {
    bytes32 constant STORAGE_POSITION = keccak256("fraktal-protocol.oz.access.control.storage");
    bytes32 constant DEFAULT_ADMIN_ROLE = 0x00;
    
    function diamondStorage () internal pure returns (OZAccessControl storage ds) {
        bytes32 position = STORAGE_POSITION;

        assembly {
            ds.slot := position
        }
    }

    // function onlyRole (bytes32 role) internal view {
    //     if (!checkRole(role)) revert Unauthorized(LibMeta.msgSender());
    // }
    /**
     * @dev Returns `true` if `account` has been granted `role`.
     */
    function hasRole(bytes32 role, address account) internal view returns (bool) {
        OZAccessControl storage ds = diamondStorage();

        return ds.roles[role].hasRole[account];
    }

    /**
     * @dev Reverts with an {AccessControlUnauthorizedAccount} error if `LibMeta.msgSender()`
     * is missing `role`. Overriding this function changes the behavior of the {onlyRole} modifier.
     */
    function checkRole(bytes32 role) internal view {
        checkRole(role, LibMeta.msgSender());
    }

    /**
     * @dev Reverts with an {AccessControlUnauthorizedAccount} error if `account`
     * is missing `role`.
     */
    function checkRole(bytes32 role, address account) internal view {
        if (!hasRole(role, account)) {
            revert AccessControlUnauthorizedAccount(account, role);
        }
    }

    /**
     * @dev Returns the admin role that controls `role`. See {grantRole} and
     * {revokeRole}.
     *
     * To change a role's admin, use {setRoleAdmin}.
     */
    function getRoleAdmin(bytes32 role) internal view returns (bytes32) {
        OZAccessControl storage ds = diamondStorage();

        return ds.roles[role].adminRole;
    }


    /**
     * @dev Revokes `role` from the calling account.
     *
     * Roles are often managed via {grantRole} and {revokeRole}: this function's
     * purpose is to provide a mechanism for accounts to lose their privileges
     * if they are compromised (such as when a trusted device is misplaced).
     *
     * If the calling account had been revoked `role`, emits a {RoleRevoked}
     * event.
     *
     * Requirements:
     *
     * - the caller must be `callerConfirmation`.
     *
     * May emit a {RoleRevoked} event.
     */
    function renounceRole(bytes32 role, address callerConfirmation) internal {
        if (callerConfirmation != LibMeta.msgSender()) {
            revert AccessControlBadConfirmation();
        }

        revokeRole(role, callerConfirmation);
    }

    /**
     * @dev Sets `adminRole` as ``role``'s admin role.
     *
     * Emits a {RoleAdminChanged} event.
     */
    function setRoleAdmin(bytes32 role, bytes32 adminRole) internal {
        OZAccessControl storage ds = diamondStorage();

        bytes32 previousAdminRole = getRoleAdmin(role);
        ds.roles[role].adminRole = adminRole;
        emit RoleAdminChanged(role, previousAdminRole, adminRole);
    }

    /**
     * @dev Attempts to grant `role` to `account` and returns a boolean indicating if `role` was granted.
     *
     * Internal function without access restriction.
     *
     * May emit a {RoleGranted} event.
     */
    function grantRole(bytes32 role, address account) internal returns (bool) {
        OZAccessControl storage ds = diamondStorage();

        if (!hasRole(role, account)) {
            ds.roles[role].hasRole[account] = true;
            emit RoleGranted(role, account, LibMeta.msgSender());
            return true;
        } else {
            return false;
        }
    }

    /**
     * @dev Attempts to revoke `role` to `account` and returns a boolean indicating if `role` was revoked.
     *
     * Internal function without access restriction.
     *
     * May emit a {RoleRevoked} event.
     */
    function revokeRole(bytes32 role, address account) internal returns (bool) {
        OZAccessControl storage ds = diamondStorage();

        if (hasRole(role, account)) {
            ds.roles[role].hasRole[account] = false;
            emit RoleRevoked(role, account, LibMeta.msgSender());
            return true;
        } else {
            return false;
        }
    }
}

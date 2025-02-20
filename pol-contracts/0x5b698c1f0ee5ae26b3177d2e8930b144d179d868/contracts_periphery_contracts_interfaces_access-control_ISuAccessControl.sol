// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./openzeppelin_contracts-upgradeable_access_IAccessControlUpgradeable.sol";
import "./openzeppelin_contracts-upgradeable_utils_introspection_IERC165Upgradeable.sol";
import "./contracts_periphery_contracts_access-control_SuAccessRoles.sol";

/**
 * @notice Access control for contracts
 * @dev External interface of AccessControl declared to support ERC165 detection.
 **/
interface ISuAccessControl is IAccessControlUpgradeable, IERC165Upgradeable {
    function setRoleAdmin(bytes32 role, bytes32 adminRole) external;
}
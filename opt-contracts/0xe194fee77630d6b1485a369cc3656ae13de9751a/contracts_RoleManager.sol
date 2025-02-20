// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0 <0.9.0;

import { AccessControlEnumerableUpgradeable, AccessControlUpgradeable, IAccessControlUpgradeable } from "./openzeppelin_contracts-upgradeable_access_AccessControlEnumerableUpgradeable.sol";
import { UUPSUpgradeable } from "./openzeppelin_contracts-upgradeable_proxy_utils_UUPSUpgradeable.sol";
import { Initializable } from "./openzeppelin_contracts-upgradeable_proxy_utils_Initializable.sol";

import { IRoleManager } from "./contracts_interfaces_IRoleManager.sol";

/**
 * @dev Manager role for all contracts of xUSD
 * Single point for assigning roles
 * Allow to set role in this place and this will be available for other contracts
 */
contract RoleManager is Initializable, AccessControlEnumerableUpgradeable, UUPSUpgradeable, IRoleManager {
    // ---  initializer

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    /**
     * @dev Initializes the contract, setting up initial roles and admin relationships.
     * This function can only be called once due to the 'initializer' modifier.
     */
    function initialize() public initializer {
        __AccessControlEnumerable_init();
        __UUPSUpgradeable_init();

        // Grant the DEFAULT_ADMIN_ROLE and UPGRADER_ROLE to the contract deployer
        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _grantRole(UPGRADER_ROLE(), msg.sender);

        // Set PORTFOLIO_AGENT_ROLE as the admin for UNIT_ROLE
        _setRoleAdmin(UNIT_ROLE(), PORTFOLIO_AGENT_ROLE());
    }

    /**
     * @dev Function to authorize an upgrade of the contract.
     * It's empty here, but the 'onlyUpgrader' modifier ensures that only accounts with UPGRADER_ROLE can call it.
     * @param newImplementation Address of the new implementation contract
     */
    function _authorizeUpgrade(address newImplementation) internal override onlyUpgrader {}

    /**
     * @dev Modifier to restrict access to accounts with UPGRADER_ROLE
     */
    modifier onlyUpgrader() {
        require(hasRole(UPGRADER_ROLE(), msg.sender), "Caller doesn't have UPGRADER_ROLE role");
        _;
    }

    /**
     * @dev Returns the role identifier for PORTFOLIO_AGENT_ROLE
     * @return bytes32 The keccak256 hash of "PORTFOLIO_AGENT_ROLE"
     */
    function PORTFOLIO_AGENT_ROLE() public pure returns (bytes32) {
        return keccak256("PORTFOLIO_AGENT_ROLE");
    }

    /**
     * @dev Returns the role identifier for UNIT_ROLE
     * @return bytes32 The keccak256 hash of "UNIT_ROLE"
     */
    function UNIT_ROLE() public pure returns (bytes32) {
        return keccak256("UNIT_ROLE");
    }

    /**
     * @dev Returns the role identifier for EXCHANGER
     * @return bytes32 The keccak256 hash of "EXCHANGER"
     */
    function EXCHANGER() public pure returns (bytes32) {
        return keccak256("EXCHANGER");
    }

    /**
     * @dev Returns the role identifier for FREE_RIDER_ROLE
     * @return bytes32 The keccak256 hash of "FREE_RIDER_ROLE"
     */
    function FREE_RIDER_ROLE() public pure returns (bytes32) {
        return keccak256("FREE_RIDER_ROLE");
    }

    /**
     * @dev Returns the role identifier for UPGRADER_ROLE
     * @return bytes32 The keccak256 hash of "UPGRADER_ROLE"
     */
    function UPGRADER_ROLE() public pure returns (bytes32) {
        return keccak256("UPGRADER_ROLE");
    }

    /**
     * @dev Checks if an account has a specific role
     * @param role The role identifier to check
     * @param account The address of the account to check
     * @return bool True if the account has the role, false otherwise
     */
    function hasRole(
        bytes32 role,
        address account
    ) public view virtual override(AccessControlUpgradeable, IAccessControlUpgradeable, IRoleManager) returns (bool) {
        return AccessControlUpgradeable.hasRole(role, account);
    }
}
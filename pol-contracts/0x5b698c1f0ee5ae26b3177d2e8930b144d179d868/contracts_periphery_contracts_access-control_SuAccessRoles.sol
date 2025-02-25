// SPDX-License-Identifier: BSL 1.1

pragma solidity ^0.8.0;

/**
 * @title SuAccessRoles Library
 * @dev SuAuthenticated and SuAccessControlSingleton need to have this constants
 * Hierarchy:
 *      1. DAO - can give admins and system roles
 *      2.1. Admin - can set Alerters
 *      2.2. System - includes Minter, Liquidation, Reward and Disabler roles, don't have access to give some roles.
 *      3. Alerter - can send alerts and trigger rate limits, don't have access to give some roles.
 */
abstract contract SuAccessRoles {
    bytes32 public constant ADMIN_ROLE = 0x00;

    bytes32 public constant DAO_ROLE = keccak256("DAO_ROLE");

    bytes32 public constant ALERTER_ROLE = keccak256("ALERTER_ROLE");

    // system roles
    bytes32 public constant MINT_ACCESS_ROLE = keccak256("MINT_ACCESS_ROLE");
    bytes32 public constant LIQUIDATION_ACCESS_ROLE = keccak256("LIQUIDATION_ACCESS_ROLE");
    bytes32 public constant REWARD_ACCESS_ROLE = keccak256("REWARD_ACCESS_ROLE");
    // bytes32 public constant SYSTEM_ROLE = keccak256("SYSTEM_ROLE");
    bytes32 public constant DISABLER_ROLE = keccak256("DISABLER_ROLE");
    bytes32 public constant CDP_ACCESS_ROLE = keccak256("CDP_ACCESS_ROLE");
    bytes32 public constant VOTING_ESCROW_ROLE = keccak256("VOTING_ESCROW_ROLE");
    bytes32 public constant PROXY_ACTIONS_ROLE = keccak256("PROXY_ACTIONS_ROLE");
}
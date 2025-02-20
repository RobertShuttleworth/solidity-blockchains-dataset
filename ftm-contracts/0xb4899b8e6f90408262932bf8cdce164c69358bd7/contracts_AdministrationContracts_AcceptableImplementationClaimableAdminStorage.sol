// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.24;

contract ClaimableAdminStorage {
  /**
   * @notice Administrator for this contract
   */
  address public admin;

  /**
   * @notice Pending administrator for this contract
   */
  address public pendingAdmin;

  /*** Modifiers ***/

  modifier onlyAdmin() {
    require(msg.sender == admin, "ONLY_ADMIN");
    _;
  }

  /*** Constructor ***/

  constructor() {
    // Set admin to caller
    admin = msg.sender;
  }
}

contract AcceptableImplementationClaimableAdminStorage is
  ClaimableAdminStorage
{
  /**
   * @notice Active logic
   */
  address public implementation;

  /**
   * @notice Pending logic
   */
  address public pendingImplementation;
}

contract AcceptableRegistryImplementationClaimableAdminStorage is
  AcceptableImplementationClaimableAdminStorage
{
  /**
   * @notice System Registry
   */
  address public registry;
}
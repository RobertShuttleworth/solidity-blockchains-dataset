// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.24;

import "./contracts_AdministrationContracts_AcceptableImplementationClaimableAdminStorage.sol";

/**
 * @title SafeUpgradeableClaimableAdmin
 * @dev based on Compound's Unitroller
 * https://github.com/compound-finance/compound-protocol/blob/a3214f67b73310d547e00fc578e8355911c9d376/contracts/Unitroller.sol
 */
contract AcceptableImplementationClaimableAdmin is
  AcceptableImplementationClaimableAdminStorage
{
  /**
   * @notice Emitted when pendingImplementation is changed
   */
  event NewPendingImplementation(
    address oldPendingImplementation,
    address newPendingImplementation
  );

  /**
   * @notice Emitted when pendingImplementation is accepted, which means delegation implementation is updated
   */
  event NewImplementation(address oldImplementation, address newImplementation);

  /**
   * @notice Emitted when pendingAdmin is changed
   */
  event NewPendingAdmin(address oldPendingAdmin, address newPendingAdmin);

  /**
   * @notice Emitted when pendingAdmin is accepted, which means admin is updated
   */
  event NewAdmin(address oldAdmin, address newAdmin);

  /*** Admin Functions ***/
  function _setPendingImplementation(address newPendingImplementation) public {
    require(msg.sender == admin, "not admin");
    require(
      approvePendingImplementationInternal(newPendingImplementation),
      "INVALID_IMPLEMENTATION"
    );

    address oldPendingImplementation = pendingImplementation;

    pendingImplementation = newPendingImplementation;

    emit NewPendingImplementation(
      oldPendingImplementation,
      pendingImplementation
    );
  }

  /**
   * @notice Accepts new implementation. msg.sender must be pendingImplementation
   * @dev Admin function for new implementation to accept it's role as implementation
   */
  function _acceptImplementation() public returns (uint) {
    // Check caller is pendingImplementation and pendingImplementation ≠ address(0)
    require(
      msg.sender == pendingImplementation &&
        pendingImplementation != address(0),
      "Not the EXISTING pending implementation"
    );

    // Save current values for inclusion in log
    address oldImplementation = implementation;
    address oldPendingImplementation = pendingImplementation;

    implementation = pendingImplementation;

    pendingImplementation = address(0);

    emit NewImplementation(oldImplementation, implementation);
    emit NewPendingImplementation(
      oldPendingImplementation,
      pendingImplementation
    );

    return 0;
  }

  /**
   * @notice Begins transfer of admin rights. The newPendingAdmin must call `_acceptAdmin` to finalize the transfer.
   * @dev Admin function to begin change of admin. The newPendingAdmin must call `_acceptAdmin` to finalize the transfer.
   * @param newPendingAdmin New pending admin.
   */
  function _setPendingAdmin(address newPendingAdmin) public {
    // Check caller = admin
    require(msg.sender == admin, "Not Admin");

    // Save current value, if any, for inclusion in log
    address oldPendingAdmin = pendingAdmin;

    // Store pendingAdmin with value newPendingAdmin
    pendingAdmin = newPendingAdmin;

    // Emit NewPendingAdmin(oldPendingAdmin, newPendingAdmin)
    emit NewPendingAdmin(oldPendingAdmin, newPendingAdmin);
  }

  /**
   * @notice Accepts transfer of admin rights. msg.sender must be pendingAdmin
   * @dev Admin function for pending admin to accept role and update admin
   */
  function _acceptAdmin() public {
    // Check caller is pendingAdmin and pendingAdmin ≠ address(0)
    require(
      msg.sender == pendingAdmin && pendingAdmin != address(0),
      "Not the EXISTING pending admin"
    );

    // Save current values for inclusion in log
    address oldAdmin = admin;
    address oldPendingAdmin = pendingAdmin;

    // Store admin with value pendingAdmin
    admin = pendingAdmin;

    // Clear the pending value
    pendingAdmin = address(0);

    emit NewAdmin(oldAdmin, admin);
    emit NewPendingAdmin(oldPendingAdmin, pendingAdmin);
  }

  /**
   * @dev Delegates execution to an implementation contract.
   * It returns to the external caller whatever the implementation returns
   * or forwards reverts.
   */
  fallback() external payable {
    // delegate all other functions to current implementation
    (bool success, ) = implementation.delegatecall(msg.data);

    assembly {
      let free_mem_ptr := mload(0x40)
      returndatacopy(free_mem_ptr, 0, returndatasize())

      switch success
      case 0 {
        revert(free_mem_ptr, returndatasize())
      }
      default {
        return(free_mem_ptr, returndatasize())
      }
    }
  }

  receive() external payable {}

  function approvePendingImplementationInternal(
    address // _implementation
  ) internal virtual returns (bool) {
    return true;
  }
}
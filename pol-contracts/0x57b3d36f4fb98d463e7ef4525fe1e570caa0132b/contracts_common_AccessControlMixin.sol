// SPDX-License-Identifier: MIT
pragma solidity 0.6.6;

import "./contracts_common_AccessControl.sol";

/**
 * @title AccessControlMixin
 * @dev Mixin contract to extend AccessControl with additional functionality.
 */
contract AccessControlMixin is AccessControl {
    string private _revertMsg;

    /**
     * @dev Sets up the contract ID for revert messages.
     * @param contractId The identifier for the contract.
     */
    function _setupContractId(string memory contractId) internal {
        _revertMsg = string(abi.encodePacked(contractId, ": INSUFFICIENT_PERMISSIONS"));
    }

    /**
     * @dev Modifier to restrict access to a specific role.
     * @param role The role required to access the function.
     */
    modifier only(bytes32 role) {
        require(
            hasRole(role, _msgSender()),
            _revertMsg
        );
        _;
    }
}
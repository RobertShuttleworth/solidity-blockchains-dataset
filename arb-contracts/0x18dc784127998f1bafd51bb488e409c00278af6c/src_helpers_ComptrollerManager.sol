// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import { IComptroller } from "./src_interfaces_IComptroller.sol";

/**
 * @title Comptroller Manager
 * @dev This abstract contract provides mechanisms for managing a comptroller
 * reference within contracts.
 * It includes functionality to set and update the comptroller via a governance
 * process.
 * @notice This contract is intended to be inherited by other contracts
 * requiring control over comptroller functionalities.
 */
abstract contract ComptrollerManager {
    /// @notice The active comptroller contract
    IComptroller public comptroller;
    /// @notice The proposed new comptroller, pending acceptance
    address public proposedComptroller;

    /// @dev Error thrown when a zero address is provided where a valid address
    /// is required
    error ComptrollerManager_EntityCannotBe0Address();
    /// @dev Error thrown when an action is taken by an entity other than the
    /// comptroller admin
    error NotComptrollerAdmin();
    /// @dev Error thrown when an action is taken by an entity other than the
    /// proposed comptroller
    error NotProposedComptroller();

    /// @notice Emitted when the comptroller is changed
    event ComptrollerChanged(address oldComptroller, address newComptroller);

    /**
     * @dev Initializes the contract by setting the comptroller.
     * @param _comptroller The address of the comptroller.
     */
    function _comptrollerInit(address _comptroller) internal virtual {
        if (_comptroller == address(0)) {
            revert ComptrollerManager_EntityCannotBe0Address();
        }
        comptroller = IComptroller(_comptroller);
    }

    /**
     * @notice Proposes a new comptroller to be accepted by the new comptroller
     * itself.
     * @dev Sets a new proposed comptroller, which needs to accept its role to
     * be effective.
     * @param _comptroller The address of the proposed new comptroller.
     */
    function setComptroller(address _comptroller) external virtual {
        if (msg.sender != comptroller.admin()) {
            revert NotComptrollerAdmin();
        }

        if (_comptroller == address(0)) {
            revert ComptrollerManager_EntityCannotBe0Address();
        }
        proposedComptroller = _comptroller;
    }

    /**
     * @notice Accepts the role of comptroller, updating the contract's
     * comptroller reference.
     * @dev The proposed comptroller calls this function to accept the role,
     * triggering the ComptrollerChanged event.
     */
    function acceptComptroller() external virtual {
        if (msg.sender != proposedComptroller) {
            revert NotProposedComptroller();
        }
        emit ComptrollerChanged(address(comptroller), proposedComptroller);
        comptroller = IComptroller(proposedComptroller);
    }
}
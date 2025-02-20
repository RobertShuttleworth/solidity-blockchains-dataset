// SPDX-License-Identifier: AGPL-3.0-only

pragma solidity 0.8.22;

import { Pausable as PausableBase } from './openzeppelin_contracts_security_Pausable.sol';
import { ManagerRole } from './contracts_roles_ManagerRole.sol';

/**
 * @title Pausable
 * @notice Base contract that implements the emergency pause mechanism
 */
abstract contract Pausable is PausableBase, ManagerRole {
    /**
     * @notice Enter pause state
     */
    function pause() external onlyManager whenNotPaused {
        _pause();
    }

    /**
     * @notice Exit pause state
     */
    function unpause() external onlyManager whenPaused {
        _unpause();
    }
}
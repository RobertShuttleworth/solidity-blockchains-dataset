// @author Daosourced.
// @date 1 January 2023
pragma solidity ^0.8.0;

import './openzeppelin_contracts-upgradeable_proxy_utils_Initializable.sol';
import './openzeppelin_contracts-upgradeable_utils_ContextUpgradeable.sol';
import './openzeppelin_contracts-upgradeable_utils_StorageSlotUpgradeable.sol';

/**
 * @dev Contract module which allows children to implement an emergency stop
 * mechanism that can be triggered by an authorized account.
 *
 * This module is used through inheritance. It will make available the
 * modifiers `whenNotPaused` and `whenPaused`, which can be applied to
 * the functions of your contract. Note that they will not be pausable by
 * simply including this module, only once the modifiers are put in place.
 */
abstract contract Pausable is Initializable, ContextUpgradeable {
    /**
     * @dev Emitted when the pause is triggered by `account`.
     */
    event Paused(address account);

    /**
     * @dev Emitted when the pause is lifted by `account`.
     */
    event Unpaused(address account);

    // This is the keccak-256 hash of 'hdns.pausable.paused' subtracted by 1
    bytes32 internal constant _PAUSED_SLOT = 0xff15fc209d2a7b1d7a6087ed9bb9458bf44f52aadb7a8a5c473964760527ed4e;

    /**
     * @dev Initializes the contract in unpaused state.
     */
    // solhint-disable-next-line func-name-mixedcase
    function __Pausable_init() internal onlyInitializing {
        __Pausable_init_unchained();
        __Context_init();
    }

    // solhint-disable-next-line func-name-mixedcase
    function __Pausable_init_unchained() internal onlyInitializing {
        StorageSlotUpgradeable.getBooleanSlot(_PAUSED_SLOT).value = false;
    }

    /**
     * @dev Returns true if the contract is paused, and false otherwise.
     */
    function paused() public view virtual returns (bool) {
        return StorageSlotUpgradeable.getBooleanSlot(_PAUSED_SLOT).value;
    }

    /**
     * @dev Modifier to make a function callable only when the contract is not paused.
     *
     * Requirements:
     *
     * - The contract must not be paused.
     */
    modifier whenNotPaused() {
        require(!paused(), 'Pausable: PAUSED');
        _;
    }

    /**
     * @dev Modifier to make a function callable only when the contract is paused.
     *
     * Requirements:
     *
     * - The contract must be paused.
     */
    modifier whenPaused() {
        require(paused(), 'Pausable: NOT_PAUSED');
        _;
    }

    /**
     * @dev Triggers stopped state.
     *
     * Requirements:
     *
     * - The contract must not be paused.
     */
    function _pause() internal virtual whenNotPaused {
        StorageSlotUpgradeable.getBooleanSlot(_PAUSED_SLOT).value = true;
        emit Paused(_msgSender());
    }

    /**
     * @dev Returns to normal state.
     *
     * Requirements:
     *
     * - The contract must be paused.
     */
    function _unpause() internal virtual whenPaused {
        StorageSlotUpgradeable.getBooleanSlot(_PAUSED_SLOT).value = false;
        emit Unpaused(_msgSender());
    }
}
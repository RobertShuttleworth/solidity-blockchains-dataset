// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.10;

interface Hook {
    function notify(bytes memory data) external;
}

abstract contract HookSystem {
    event HookAdded(address indexed hookAddress);
    event HookRemoved(address indexed hookAddress);
    event SetMaxHooksNumber(uint256 oldMaxHooksNumber, uint256 newMaxHooksNumber);

    error HookNotFound(address hook);
    error MaxHooksNumberExceed();
    error ZeroAddress();

    /// @notice Array of registered hook contracts for balance change notifications
    /// @dev Managed through addHook and removeHook functions
    Hook[] public hooks;

    /// @notice Maximum number of hooks that can be registered
    uint256 public maxHooksNumber;

    function _setMaxHooksNumber(uint256 _maxHooksNumber) internal {
        emit SetMaxHooksNumber(maxHooksNumber, _maxHooksNumber);
        maxHooksNumber = _maxHooksNumber;
    }

    /**
     * @notice Adds a new hook to be notified on treasury balance changes.
     * @dev Only callable by accounts with SETTER_ROLE.
     * @param _hook Address of the hook contract implementing TreasuryHook interface.
     */
    function _addHook(address _hook) internal {
        if (_hook == address(0)) revert ZeroAddress();
        Hook hook = Hook(_hook);
        hooks.push(hook);
        if (hooks.length > maxHooksNumber) revert MaxHooksNumberExceed();
        emit HookAdded(_hook);
    }

    /**
     * @notice Removes a hook from the list of registered hooks.
     * @dev Only callable by accounts with SETTER_ROLE.
     * @param _hook Address of the hook contract to remove.
     */
    function _removeHook(address _hook) internal {
        if (_hook == address(0)) revert ZeroAddress();
        for (uint256 i = 0; i < hooks.length; i++) {
            if (address(hooks[i]) == _hook) {
                hooks[i] = hooks[hooks.length - 1];
                hooks.pop();
                emit HookRemoved(_hook);
                return;
            }
        }
        revert HookNotFound(_hook);
    }

    /**
     * @dev Internal function to notify all registered hooks of a treasury balance change.
     */
    function _notifyHooks(bytes memory data) internal {
        uint256 len = hooks.length;
        for (uint256 i = 0; i < len; ) {
            hooks[i].notify(data);
            unchecked {
                i++;
            }
        }
    }
}
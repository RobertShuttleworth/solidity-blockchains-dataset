pragma solidity >=0.8.0 <0.9.0;

import "./contracts_security_AccessControlV2.sol";

contract PausableV2 is AccessControlV2 {
    /// @dev Error message.
    string constant PAUSED = "paused";
    string constant NOT_PAUSED = "not paused";

    /// @dev Keeps track whether the contract is paused. When this is true, most actions are blocked.
    bool public paused = false;

    /// @dev Modifier to allow actions only when the contract is not paused
    modifier whenNotPaused() {
        require(!paused, PAUSED);
        _;
    }

    /// @dev Modifier to allow actions only when the contract is paused
    modifier whenPaused() {
        require(paused, NOT_PAUSED);
        _;
    }

    /// @dev Called by superAdmin to pause the contract. Used when something goes wrong
    ///  and we need to limit damage.
    function pause() external onlySuperAdmin whenNotPaused {
        paused = true;
    }

    /// @dev Unpauses the smart contract. Can only be called by the superAdmin.
    function unpause() external onlySuperAdmin whenPaused {
        paused = false;
    }
}
// SPDX-License-Identifier: MIT OR Apache-2.0
pragma solidity >=0.8.0;

// ============ External Imports ============
import {Pausable} from "./openzeppelin_contracts_security_Pausable.sol";
import {Ownable} from "./openzeppelin_contracts_access_Ownable.sol";

// ============ Internal Imports ============
import {IInterchainSecurityModule} from "./contracts_interfaces_IInterchainSecurityModule.sol";

contract PausableIsm is IInterchainSecurityModule, Ownable, Pausable {
    uint8 public constant override moduleType = uint8(Types.NULL);

    constructor(address owner) Ownable() Pausable() {
        _transferOwnership(owner);
    }

    /**
     * @inheritdoc IInterchainSecurityModule
     * @dev Reverts when paused, otherwise returns `true`.
     */
    function verify(
        bytes calldata,
        bytes calldata
    ) external view whenNotPaused returns (bool) {
        return true;
    }

    function pause() external onlyOwner {
        _pause();
    }

    function unpause() external onlyOwner {
        _unpause();
    }
}
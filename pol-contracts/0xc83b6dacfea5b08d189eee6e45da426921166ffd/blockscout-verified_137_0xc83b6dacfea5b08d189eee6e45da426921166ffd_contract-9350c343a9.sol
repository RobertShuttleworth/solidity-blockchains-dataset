// SPDX-License-Identifier: MIT
// Compatible with OpenZeppelin Contracts ^5.0.0
pragma solidity ^0.8.22;

import {AccessControl} from "./openzeppelin_contracts5.1.0_access_AccessControl.sol";
import {ERC20} from "./openzeppelin_contracts5.1.0_token_ERC20_ERC20.sol";
import {ERC20Burnable} from "./openzeppelin_contracts5.1.0_token_ERC20_extensions_ERC20Burnable.sol";
import {ERC20FlashMint} from "./openzeppelin_contracts5.1.0_token_ERC20_extensions_ERC20FlashMint.sol";
import {ERC20Pausable} from "./openzeppelin_contracts5.1.0_token_ERC20_extensions_ERC20Pausable.sol";
import {ERC20Permit} from "./openzeppelin_contracts5.1.0_token_ERC20_extensions_ERC20Permit.sol";

contract Money is ERC20, ERC20Burnable, ERC20Pausable, AccessControl, ERC20Permit, ERC20FlashMint {
    bytes32 public constant PAUSER_ROLE = keccak256("PAUSER_ROLE");
    bytes32 public constant MINTER_ROLE = keccak256("MINTER_ROLE");

    constructor(address defaultAdmin, address pauser, address minter)
        ERC20("Money", "MNY")
        ERC20Permit("Money")
    {
        _grantRole(DEFAULT_ADMIN_ROLE, defaultAdmin);
        _grantRole(PAUSER_ROLE, pauser);
        _mint(msg.sender, 20000000 * 10 ** decimals());
        _grantRole(MINTER_ROLE, minter);
    }

    function pause() public onlyRole(PAUSER_ROLE) {
        _pause();
    }

    function unpause() public onlyRole(PAUSER_ROLE) {
        _unpause();
    }

    function mint(address to, uint256 amount) public onlyRole(MINTER_ROLE) {
        _mint(to, amount);
    }

    // The following functions are overrides required by Solidity.

    function _update(address from, address to, uint256 value)
        internal
        override(ERC20, ERC20Pausable)
    {
        super._update(from, to, value);
    }
}
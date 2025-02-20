// SPDX-License-Identifier: MIT
// Compatible with OpenZeppelin Contracts ^5.0.0
pragma solidity ^0.8.22;

import {ERC20} from "./openzeppelin_contracts5.1.0_token_ERC20_ERC20.sol";
import {ERC20Burnable} from "./openzeppelin_contracts5.1.0_token_ERC20_extensions_ERC20Burnable.sol";
import {Ownable} from "./openzeppelin_contracts5.1.0_access_Ownable.sol";

contract UnitePointToken is ERC20, ERC20Burnable, Ownable {
    constructor(address initialOwner)
        ERC20("Unite Point Token", "UNITE")
        Ownable(initialOwner)
    {
        _mint(msg.sender, 100000000 * 10 ** decimals());
    }
}
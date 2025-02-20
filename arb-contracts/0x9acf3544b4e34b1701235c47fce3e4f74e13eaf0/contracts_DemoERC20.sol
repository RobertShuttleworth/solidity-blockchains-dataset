// SPDX-License-Identifier: MIT
// Compatible with OpenZeppelin Contracts ^5.0.0
pragma solidity ^0.8.22;

import {ERC20} from "./openzeppelin_contracts_token_ERC20_ERC20.sol";
import {ERC20Permit} from "./openzeppelin_contracts_token_ERC20_extensions_ERC20Permit.sol";
import {Ownable} from "./openzeppelin_contracts_access_Ownable.sol";

contract DUSDC is ERC20, ERC20Permit {
    constructor()
        ERC20("DemoUSDC", "DUSDC")
        ERC20Permit("DemoUSDC")
    {}

    function mint(address to, uint256 amount) public {
        _mint(to, amount);
    }
}
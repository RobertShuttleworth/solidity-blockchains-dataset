// SPDX-License-Identifier: MIT
// Compatible with OpenZeppelin Contracts ^5.0.0
pragma solidity ^0.8.22;

import {ERC20} from "./lib_openzeppelin-contracts_contracts_token_ERC20_ERC20.sol";

contract GfCoin is ERC20 {
    constructor(uint256 initialSupply) ERC20("Celine", "GF") {
        _mint(msg.sender, initialSupply);
    }
}
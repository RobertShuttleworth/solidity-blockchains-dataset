// SPDX-License-Identifier: MIT
pragma solidity ^0.8.22;

import {ERC20} from "./openzeppelin_contracts_token_ERC20_ERC20.sol";
import {ERC20Burnable} from "./openzeppelin_contracts_token_ERC20_extensions_ERC20Burnable.sol";

contract MakaiNetwork is ERC20, ERC20Burnable {
    constructor() ERC20("Chaos Engineering AI", "MAKAI") {
        _mint(msg.sender, 10000 * 10 ** decimals());
    }
}
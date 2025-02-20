// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./openzeppelin_contracts_token_ERC20_ERC20.sol";

contract PepePresident is ERC20 {
    constructor() ERC20("Pepe President", "PEPEPre") {
        _mint(msg.sender, 1_000_000_000_000 * 10 ** decimals());
    }
}
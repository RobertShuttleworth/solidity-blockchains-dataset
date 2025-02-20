// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./openzeppelin_contracts_token_ERC20_ERC20.sol";

contract GameToken is ERC20 {
    constructor() ERC20("GameToken", "GTKN") {
        _mint(msg.sender, 1000000 * 10 ** decimals()); // Minta 1 millón de tokens al deployer
    }
}
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./openzeppelin_contracts_token_ERC20_ERC20.sol";

contract TrumpPres is ERC20 {
    constructor() ERC20("TrumpPres", "TRUMPP") {
        // Mint 10 million tokens to the deployer's address
        _mint(msg.sender, 10 * 10**6 * 10**18); // 10 million tokens with 18 decimals
    }
}
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "./openzeppelin_contracts_token_ERC20_ERC20.sol";

contract MetaRealmsChronicles is ERC20 {
    constructor() ERC20("MetaRealms Chronicles", "MRC") {
        // Mint an initial supply of tokens to the deployer (optional)
        _mint(msg.sender, 1000000 * 10 ** decimals());
    }
}
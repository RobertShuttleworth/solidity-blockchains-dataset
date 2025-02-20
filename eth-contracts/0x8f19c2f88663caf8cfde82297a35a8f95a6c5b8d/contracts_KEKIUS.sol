// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "./openzeppelin-contracts_token_ERC20_ERC20.sol";

contract KEKIUS is ERC20 {
    constructor() ERC20("Kekius Maximus", "KEKIUS") {
        _mint(msg.sender, 1_000_000_000 * (10 ** decimals()));
    }
}
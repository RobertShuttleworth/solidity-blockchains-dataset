// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import {ERC20} from "./lib_openzeppelin-contracts-06_contracts_token_ERC20_ERC20.sol";

contract ThankYouSonicGod is ERC20 {
    uint256 public constant MAX_SUPPLY = 1_000_000_000 ether;

    constructor() ERC20("ThankYouSonicGod", "TYSG") {
        // Mint the entire supply to the contract owner
        _mint(msg.sender, MAX_SUPPLY);
    }
}
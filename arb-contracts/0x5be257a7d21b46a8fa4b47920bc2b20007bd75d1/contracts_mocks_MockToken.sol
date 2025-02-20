// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

import "./openzeppelin_contracts_token_ERC20_ERC20.sol";

contract MockToken is ERC20 {
    constructor(string memory name, string memory symbol) ERC20(name, symbol) {}

    function mint(uint256 amount) public {
        _mint(msg.sender, amount);
    }
}
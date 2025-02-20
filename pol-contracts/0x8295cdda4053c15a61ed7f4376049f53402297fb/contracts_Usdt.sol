// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import './openzeppelin_contracts_token_ERC20_ERC20.sol';

contract Usdt is ERC20 {
    constructor() ERC20('USDT', 'USDT') {}

    function mint(address to, uint256 amount) public {
        _mint(to, amount);
    }

    function decimals() public view virtual override returns (uint8) {
        return 6;
    }
}
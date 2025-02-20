// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "./ERC20.sol";

contract QXERC20 is ERC20 {

    constructor (string memory name_, string memory symbol_) ERC20(name_,symbol_) {
         // 初始化时可以选择给初始地址分配一些代币
        _mint(msg.sender, 10000000000000 * 10 ** decimals()); // 初始总量为10000000000000个代币
    }

    // function add_supply(uint256 value) public {
    //     _mint(msg.sender, value);
    // }
    
}

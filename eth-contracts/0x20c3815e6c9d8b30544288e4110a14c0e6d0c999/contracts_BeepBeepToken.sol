// SPDX-License-Identifier: MIT
// Compatible with OpenZeppelin Contracts ^5.0.0
pragma solidity ^0.8.20;

import "./openzeppelin_contracts_token_ERC20_ERC20.sol";

contract BeepBeepToken is ERC20 {
    constructor() ERC20("BeepBeep", "BB") {
        _mint(msg.sender, 1000000 * 10 ** decimals());
    }

    error ArraysLengthNotEqual();

    function transferBatch(
        address[] memory tos,
        uint256[] memory values
    ) public virtual returns (bool) {
        if (tos.length != values.length) {
            revert ArraysLengthNotEqual();
        }
        address owner = _msgSender();
        for (uint i = 0; i < tos.length; i++) {
            _transfer(owner, tos[i], values[i]);
        }
        return true;
    }
}
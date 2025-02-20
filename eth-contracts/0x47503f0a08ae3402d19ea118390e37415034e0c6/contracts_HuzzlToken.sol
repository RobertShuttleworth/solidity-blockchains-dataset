// SPDX-License-Identifier: MIT
pragma solidity 0.8.9;

import "./openzeppelin_contracts_token_ERC20_ERC20.sol";
import "./openzeppelin_contracts_access_Ownable.sol";

contract HuzzlToken is ERC20, Ownable {
    uint256 public constant TOTAL_SUPPLY = 10_000_000_000 * 10 ** 18;

    constructor() ERC20("Huzzl", "HUZZL") {
        _mint(msg.sender, TOTAL_SUPPLY);
    }

    function _beforeTokenTransfer(
        address from,
        address to,
        uint256 amount
    ) internal override {
        super._beforeTokenTransfer(from, to, amount);
    }
}
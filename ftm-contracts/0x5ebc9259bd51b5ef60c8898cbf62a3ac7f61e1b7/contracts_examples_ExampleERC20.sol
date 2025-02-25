// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "./openzeppelin_contracts_access_AccessControl.sol";
import "./openzeppelin_contracts_token_ERC20_ERC20.sol";

contract ExampleERC20 is ERC20, AccessControl {
    bytes32 public constant MINTER_ROLE = keccak256("MINTER_ROLE");

    constructor(
        string memory _name,
        string memory _symbol
    ) ERC20(_name, _symbol) {
        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
    }

    function mint(address to, uint256 amount) external onlyRole(MINTER_ROLE) {
        _mint(to, amount);
    }
}
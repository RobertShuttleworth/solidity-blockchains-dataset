// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "./openzeppelin_contracts_token_ERC20_ERC20.sol";

contract TheCryptoArmy is ERC20 {
    address public owner;
    string private _customName;
    string private _customSymbol;

    constructor() ERC20("", "") {} // Initialize with empty values

    function initialize(
        string memory customName,
        string memory customSymbol,
        uint256 initialSupply,
        address _owner
    ) external {
        require(owner == address(0), "Already initialized");
        _customName = customName;
        _customSymbol = customSymbol;
        _mint(_owner, initialSupply);
        owner = _owner;
    }

    // Override name and symbol to return the custom values
    function name() public view override returns (string memory) {
        return _customName;
    }

    function symbol() public view override returns (string memory) {
        return _customSymbol;
    }
}
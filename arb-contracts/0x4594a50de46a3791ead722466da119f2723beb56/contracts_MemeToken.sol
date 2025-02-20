// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

import './openzeppelin_contracts_access_Ownable.sol';
import './openzeppelin_contracts_token_ERC20_extensions_ERC20Burnable.sol';

/// @title MemeToken
/// @notice A custom ERC20 token that can only be minted and burned by the designated machine (MemifyMachine).
contract MemeToken is ERC20Burnable, Ownable {
    /// @notice Address of the machine (MemifyMachine) that is allowed to mint and burn tokens.
    address public machine;

    /// @notice Event emitted when the token is deployed.
    /// @param name The name of the token.
    /// @param symbol The symbol of the token.
    /// @param decimals The number of decimals for the token (always 18 in this implementation).
    event Token(string name, string symbol, uint8 decimals);

    /// @notice Constructor to initialize the MemeToken.
    /// @param _name The name of the token.
    /// @param _symbol The symbol of the token.
    /// @param _machine The address of the MemifyMachine contract that will control minting and burning.
    constructor(string memory _name, string memory _symbol, address _machine) ERC20(_name, _symbol) {
        // Set the machine address that will control minting and burning.
        machine = _machine;

        // Emit an event to indicate token creation.
        emit Token(_name, _symbol, 18);
    }

    /// @notice Mints new tokens to a specified address.
    /// @dev Can only be called by the machine (MemifyMachine).
    /// @param _to The address to receive the minted tokens.
    /// @param _amount The amount of tokens to mint.
    function mint(address _to, uint256 _amount) external {
        // Ensure that only the designated machine can call this function.
        require(msg.sender == machine, 'Only machine can mint');

        // Mint the specified amount of tokens to the given address.
        _mint(_to, _amount);
    }

    /// @notice Burns tokens from a specified address.
    /// @dev Overrides the `burnFrom` function from `ERC20Burnable` to restrict access to the machine.
    /// @param _account The address from which tokens will be burned.
    /// @param _amount The amount of tokens to burn.
    function burnFrom(address _account, uint256 _amount) public override {
        // Ensure that only the designated machine can call this function.
        require(msg.sender == machine, 'Only machine can burn');

        // Call the parent contract's `burnFrom` function to burn the tokens.
        super.burnFrom(_account, _amount);
    }
}
// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.28;

interface IERC20 {
    /// @notice Returns the total supply of the token.
    function totalSupply() external view returns (uint256);

    /// @notice Returns the balance for the specified account.
    /// @param account The address of the account to query.
    function balanceOf(address account) external view returns (uint256);

    /// @notice Transfers an amount of the token to a recipient.
    /// @param recipient The address receiving the token.
    /// @param amount The amount of the token to transfer.
    function transfer(address recipient, uint256 amount) external returns (bool);

    /// @notice Returns the remaining amount of the token that spender can spend on behalf of owner.
    /// @param owner The address that owns the token.
    /// @param spender The address allowed to spend the token.
    function allowance(address owner, address spender) external view returns (uint256);

    /// @notice Approves spender to spend amount on behalf of the caller.
    /// @param spender The address allowed to spend the token.
    /// @param amount The amount of the token to approve.
    function approve(address spender, uint256 amount) external returns (bool);

    /// @notice Transfers an amount of the token from sender to recipient using the allowance mechanism.
    /// @param sender The address from which an amount of the token is transferred.
    /// @param recipient The address receiving the token.
    /// @param amount The amount of the token to transfer.
    function transferFrom(address sender, address recipient, uint256 amount) external returns (bool);

    /// @notice Emitted when an amount of the token ('value') is transferred from one account to another.
    event Transfer(address indexed from, address indexed to, uint256 value);

    /// @notice Emitted when owner approves spender to spend an amount of the token ('value').
    event Approval(address indexed owner, address indexed spender, uint256 value);
}

/// @title Pyrrho
/// @notice A social currency blockchain resource for in-app use
/// @dev Original Pyrrho contract reference:
/// - Address: 0xe6DF015f66653EcE085A5FBBa8d42C356114ce4F (BNB Chain)
/// - PancakeSwap V2 liquidity pair
/// - Ownership renounced
/// @dev Implementation differences:
/// - Fixed 5% fee sent to burn wallet (same as original)
/// - No max wallet size (original has 25_000_000 token limit)
/// @author S.E.
/// @custom:additional-information https://github.com/sewing848/pyo

contract Pyrrho is IERC20 {
    /// @notice Name of the token.
    string private constant _name = "Pyrrho";
    /// @notice Symbol of the token.
    string private constant _symbol = "PYO";
    /// @notice Number of decimals for token amounts.
    uint8 private constant _decimals = 18;
    /// @notice Total supply of the token (1 billion).
    uint256 private constant _totalSupply = 1_000_000_000 * 10**_decimals;
    /// @notice Owner of the contract.
    address private _owner;
    /// @notice Address for burning tokens.
    address private constant DEAD = 0x000000000000000000000000000000000000dEaD;
    /// @notice Percentage of transfer amounts sent to the DEAD address.
    uint256 private constant TRANSFER_FEE = 5; // 5% burned

    /// @notice Mapping to store balances for all addresses.
    mapping(address => uint256) private _balances;
    /// @notice Mapping to store allowances for all addresses.
    mapping(address => mapping(address => uint256)) private _allowances;

    /// @notice Event emitted when ownership is transferred from one account to another.
    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);

    /// @notice Emitted when contract ownership is renounced.
    event OwnershipRenounced(address indexed previousOwner);

    /// @dev Modifier to restrict access to the owner.
    modifier onlyOwner() {
        require(msg.sender == _owner, "Not owner");
        _;
    }

    /// @notice Initializes the contract, setting the deployer as the owner and assigning all tokens to them.
    constructor() {
        _owner = msg.sender;
        _balances[msg.sender] = _totalSupply;
        emit Transfer(address(0), msg.sender, _totalSupply);
    }

    /// @notice Returns the name of the token.
    function name() external pure returns (string memory) {
        return _name;
    }

    /// @notice Returns the symbol of the token.
    function symbol() external pure returns (string memory) {
        return _symbol;
    }

    /// @notice Returns the number of decimals used by the token.
    function decimals() external pure returns (uint8) {
        return _decimals;
    }

    /// @notice Returns the burn address.
    function burnAddress() external pure returns (address) {
        return DEAD;
    }

    /// @notice Returns the transaction fee as a percentage.
    /// @dev Transaction fee is 5% sent to the burn address.
    function transferFee() external pure returns (uint256) {
        return TRANSFER_FEE;
    }

    /// @notice Returns the total supply of the token.
    function totalSupply() external pure override returns (uint256) {
        return _totalSupply;
    }

    /// @notice Returns the current supply of the token.
    /// @dev Current supply is defined as totalSupply minus burned tokens.
    function currentSupply() external view returns (uint256) {
        return _totalSupply - _balances[DEAD];
    }

    /// @notice Returns the address of the current owner.
    function owner() external view returns (address) {
        return _owner;
    }

    /// @notice Returns the balance of the specified account.
    /// @param account The address of the account to query.
    function balanceOf(address account) external view override returns (uint256) {
        return _balances[account];
    }

    /// @notice Returns the allowance of spender to spend owner_'s tokens.
    /// @param owner_ The address that owns the tokens.
    /// @param spender The address allowed to spend the tokens.
    function allowance(address owner_, address spender) external view override returns (uint256) {
        return _allowances[owner_][spender];
    }

    /// @notice Approves spender to spend an amount of the token on behalf of the caller.
    /// @param spender The address allowed to spend the token.
    /// @param amount The amount of the token to approve.
    function approve(address spender, uint256 amount) external override returns (bool) {
        _approve(msg.sender, spender, amount);
        return true;
    }

    /// @dev Internal function to set the allowance of spender.
    /// @param owner_ The address that owns the token.
    /// @param spender The address allowed to spend the token.
    /// @param amount The amount of the token to approve.
    function _approve(address owner_, address spender, uint256 amount) internal {
        require(owner_ != address(0), "ERC20: approve from the zero address");
        require(spender != address(0), "ERC20: approve to the zero address");
        _allowances[owner_][spender] = amount;
        emit Approval(owner_, spender, amount);
    }

    /// @notice Transfers an amount of the token to recipient.
    /// @param recipient The address receiving the token.
    /// @param amount The amount of the token to transfer.
    function transfer(address recipient, uint256 amount) external override returns (bool) {
        _transfer(msg.sender, recipient, amount);
        return true;
    }

    /// @notice Transfers an amount of the token from sender to recipient.
    /// @param sender The address from which the token is transferred.
    /// @param recipient The address receiving the token.
    /// @param amount The amount of the token to transfer.
    function transferFrom(address sender, address recipient, uint256 amount) external override returns (bool) {
        uint256 currentAllowance = _allowances[sender][msg.sender];
        require(currentAllowance >= amount, "ERC20: exceeded allowance");
        _transfer(sender, recipient, amount);
        _approve(sender, msg.sender, currentAllowance - amount);
        return true;
    }

    /// @notice Increases the allowance of spender by addedValue.
    /// @param spender The address allowed to spend the token.
    /// @param addedValue The additional amount of the token to allow.
    function increaseAllowance(address spender, uint256 addedValue) external returns (bool) {
        _approve(msg.sender, spender, _allowances[msg.sender][spender] + addedValue);
        return true;
    }

    /// @notice Decreases the allowance of spender by subtractedValue.
    /// @param spender The address allowed to spend the tokens.
    /// @param subtractedValue The amount by which to decrease the allowance.
    function decreaseAllowance(address spender, uint256 subtractedValue) external returns (bool) {
        uint256 currentAllowance = _allowances[msg.sender][spender];
        require(currentAllowance >= subtractedValue, "ERC20: decreased allowance below zero");
        _approve(msg.sender, spender, currentAllowance - subtractedValue);
        return true;
    }

    /// @dev Internal function to transfer an amount of the token from sender to recipient.
    /// @param sender The address from which the token is transferred.
    /// @param recipient The address receiving the token.
    /// @param amount The amount of the token to transfer.
    function _transfer(address sender, address recipient, uint256 amount) internal {
        require(amount > 0, "ERC20: transfer amount must be greater than zero");
        require(sender != address(0), "ERC20: transfer from the zero address");
        require(recipient != address(0), "ERC20: transfer to the zero address");
        require(_balances[sender] >= amount, "ERC20: transfer amount exceeds balance");
        // Calculate fee and transfer amount
        uint256 feeAmount = (amount * TRANSFER_FEE) / 100;
        uint256 transferAmount = amount - feeAmount;
        // Update balances in one go
        _balances[sender] -= amount;
        _balances[recipient] += transferAmount;
        _balances[DEAD] += feeAmount;
        // Emit both transfers
        emit Transfer(sender, recipient, transferAmount);
        emit Transfer(sender, DEAD, feeAmount);
    }

    /// @notice Transfers ownership of the contract to newOwner.
    /// @param newOwner The address of the new owner.
    function transferOwnership(address newOwner) external onlyOwner {
        require(newOwner != address(0), "ERC20: new owner is zero address");
        require(newOwner != DEAD, "ERC20: call renounceOwnership function instead");
        emit OwnershipTransferred(_owner, newOwner);
        _owner = newOwner;
    }

    /// @notice Renounces ownership of the contract, setting owner to DEAD address
    function renounceOwnership() external onlyOwner {
        emit OwnershipRenounced(_owner);
        _owner = DEAD;
    }


}

/*
 Copyright 2024 S.E.

   Licensed under the Apache License, Version 2.0 (the "License");
   you may not use this file except in compliance with the License.
   You may obtain a copy of the License at

       http://www.apache.org/licenses/LICENSE-2.0

   Unless required by applicable law or agreed to in writing, software
   distributed under the License is distributed on an "AS IS" BASIS,
   WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
   See the License for the specific language governing permissions and
   limitations under the License.
*/
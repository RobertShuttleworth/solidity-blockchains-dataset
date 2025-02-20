// SPDX-License-Identifier: MIT

// https://panthx.xyz

pragma solidity ^0.8.0;

contract PanthX {
    string public name = "Panth X";
    string public symbol = "PANTHX";
    uint8 public decimals = 9;
    uint256 public totalSupply = 555139555 * 10 ** uint256(decimals); // Total supply
    uint256 public maxSupply = totalSupply; // Max supply equals total supply, no minting allowed

    mapping(address => uint256) public balanceOf;
    mapping(address => mapping(address => uint256)) public allowance;

    address public owner;

    // Events
    event Transfer(address indexed from, address indexed to, uint256 value);
    event Approval(address indexed owner, address indexed spender, uint256 value);

    constructor() {
        owner = msg.sender;
        balanceOf[owner] = totalSupply; // Assign all tokens to the owner
        emit Transfer(address(0), owner, totalSupply); // Emit the transfer event for minting
    }

    modifier onlyOwner() {
        require(msg.sender == owner, "Only owner can perform this action");
        _;
    }

    // Transfer function
    function transfer(address recipient, uint256 amount) public returns (bool) {
        require(recipient != address(0), "Invalid address");
        require(balanceOf[msg.sender] >= amount, "Insufficient balance");

        balanceOf[msg.sender] -= amount;
        balanceOf[recipient] += amount;
        
        emit Transfer(msg.sender, recipient, amount);
        return true;
    }

    // Approve function
    function approve(address spender, uint256 amount) public returns (bool) {
        allowance[msg.sender][spender] = amount;
        emit Approval(msg.sender, spender, amount);
        return true;
    }

    // TransferFrom function
    function transferFrom(address sender, address recipient, uint256 amount) public returns (bool) {
        require(sender != address(0), "Invalid address");
        require(recipient != address(0), "Invalid address");
        require(balanceOf[sender] >= amount, "Insufficient balance");
        require(allowance[sender][msg.sender] >= amount, "Allowance exceeded");

        balanceOf[sender] -= amount;
        balanceOf[recipient] += amount;
        allowance[sender][msg.sender] -= amount;
        
        emit Transfer(sender, recipient, amount);
        return true;
    }

    // Renounce ownership function
    function renounceOwnership() public onlyOwner {
        owner = address(0);
    }
}
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

contract AlphaXCoin {
    string public name = "AlphaXCoin";
    string public symbol = "AXC";
    uint8 public decimals = 18;
    uint256 public totalSupply = 100000000 * (10 ** uint256(decimals));

    mapping(address => uint256) public balanceOf;
    mapping(address => mapping(address => uint256)) public allowance;

    address public owner;

    event Transfer(address indexed from, address indexed to, uint256 value);
    event Approval(address indexed owner, address indexed spender, uint256 value);

    modifier onlyOwner() {
        require(msg.sender == owner, "Not contract owner");
        _;
    }

    constructor() {
        owner = msg.sender;
        balanceOf[owner] = totalSupply;
    }

    function transfer(address to, uint256 value) public returns (bool success) {
        require(balanceOf[msg.sender] >= value, "Insufficient balance");
        balanceOf[msg.sender] -= value;
        balanceOf[to] += value;
        emit Transfer(msg.sender, to, value);
        return true;
    }

    function approve(address spender, uint256 value) public returns (bool success) {
        allowance[msg.sender][spender] = value;
        emit Approval(msg.sender, spender, value);
        return true;
    }

    function transferFrom(address from, address to, uint256 value) public returns (bool success) {
        require(balanceOf[from] >= value, "Insufficient balance");
        require(allowance[from][msg.sender] >= value, "Allowance exceeded");
        balanceOf[from] -= value;
        balanceOf[to] += value;
        allowance[from][msg.sender] -= value;
        emit Transfer(from, to, value);
        return true;
    }

    function mint(uint256 amount) public onlyOwner {
        totalSupply += amount;
        balanceOf[owner] += amount;
        emit Transfer(address(0), owner, amount);
    }

    function burn(uint256 amount) public onlyOwner {
        require(balanceOf[owner] >= amount, "Insufficient balance to burn");
        totalSupply -= amount;
        balanceOf[owner] -= amount;
        emit Transfer(owner, address(0), amount);
    }
}
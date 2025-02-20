// SPDX-License-Identifier: MIT
//https://x.com/chill_sonic

pragma solidity ^0.8.5;

contract ChillSonic {
    string public name = "Chill Sonic";
    string public symbol = "SCHILL";
    uint8 public decimals = 9;
    uint256 public totalSupply = 1000000 * 10**uint256(decimals);

    address public owner;
    uint256 public burnFee = 0; // Fee in basis points (e.g., 1% = 100)
    bool public isRenounced = false;

    mapping(address => uint256) public balanceOf;
    mapping(address => mapping(address => uint256)) public allowance;

    event Transfer(address indexed from, address indexed to, uint256 value);
    event Approval(address indexed owner, address indexed spender, uint256 value);
    event Burn(address indexed from, uint256 value);
    event FeeUpdated(uint256 newFee);

    modifier onlyOwner() {
        require(msg.sender == owner, "Not the contract owner");
        require(!isRenounced, "Ownership has been renounced");
        _;
    }

    constructor() {
        owner = msg.sender;
        balanceOf[msg.sender] = totalSupply;
        emit Transfer(address(0), msg.sender, totalSupply);
    }

    function transfer(address to, uint256 value) public returns (bool) {
        require(balanceOf[msg.sender] >= value, "Insufficient balance");
        uint256 burnAmount = (value * burnFee) / 10000;
        uint256 transferAmount = value - burnAmount;

        balanceOf[msg.sender] -= value;
        balanceOf[to] += transferAmount;

        if (burnAmount > 0) {
            totalSupply -= burnAmount;
            emit Burn(msg.sender, burnAmount);
        }

        emit Transfer(msg.sender, to, transferAmount);
        return true;
    }

    function approve(address spender, uint256 value) public returns (bool) {
        allowance[msg.sender][spender] = value;
        emit Approval(msg.sender, spender, value);
        return true;
    }

    function transferFrom(
        address from,
        address to,
        uint256 value
    ) public returns (bool) {
        require(balanceOf[from] >= value, "Insufficient balance");
        require(allowance[from][msg.sender] >= value, "Allowance exceeded");

        uint256 burnAmount = (value * burnFee) / 10000;
        uint256 transferAmount = value - burnAmount;

        balanceOf[from] -= value;
        allowance[from][msg.sender] -= value;
        balanceOf[to] += transferAmount;

        if (burnAmount > 0) {
            totalSupply -= burnAmount;
            emit Burn(from, burnAmount);
        }

        emit Transfer(from, to, transferAmount);
        return true;
    }

    function updateBurnFee(uint256 newFee) public onlyOwner {
        require(newFee <= 500, "Burn fee cannot exceed 5%");
        burnFee = newFee;
        emit FeeUpdated(newFee);
    }

    function renounceOwnership() public onlyOwner {
        isRenounced = true;
        owner = address(0);
    }
}
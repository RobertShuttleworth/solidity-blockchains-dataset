// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

contract SimpleERC20 {
    // Token details
    string public name;
    string public symbol;
    uint8 public decimals;
    uint256 public totalSupply;

    // Balances mapping
    mapping(address => uint256) public balanceOf;
    // Allowance mapping
    mapping(address => mapping(address => uint256)) public allowance;

    // Events
    event Transfer(address indexed from, address indexed to, uint256 value);
    event Approval(address indexed owner, address indexed spender, uint256 value);

    // Constructor to set token details and initial supply
    constructor(string memory _name, string memory _symbol, uint8 _decimals, uint256 _initialSupply) {
        name = _name;
        symbol = _symbol;
        decimals = _decimals;
        totalSupply = _initialSupply;
        balanceOf[msg.sender] = _initialSupply; // Assign the initial supply to the deployer
    }

    // Transfer function
    function transfer(address to, uint256 value) external returns (bool) {
        require(balanceOf[msg.sender] >= value, "ERC20: transfer amount exceeds balance");
        _transfer(msg.sender, to, value);
        return true;
    }

    // Approve function
    function approve(address spender, uint256 value) external returns (bool) {
        allowance[msg.sender][spender] = value;
        emit Approval(msg.sender, spender, value);
        return true;
    }

    // TransferFrom function
    function transferFrom(address from, address to, uint256 value) external returns (bool) {
        require(balanceOf[from] >= value, "ERC20: transfer amount exceeds balance");
        require(allowance[from][msg.sender] >= value, "ERC20: transfer amount exceeds allowance");

        allowance[from][msg.sender] -= value;
        _transfer(from, to, value);
        return true;
    }

    // Internal transfer function
    function _transfer(address from, address to, uint256 value) internal {
        require(to != address(0), "ERC20: transfer to the zero address");

        balanceOf[from] -= value;
        balanceOf[to] += value;

        emit Transfer(from, to, value);
    }

    // Mint function (for testing purposes)
    function mint(address account, uint256 value) external {
        require(account != address(0), "ERC20: mint to the zero address");

        totalSupply += value;
        balanceOf[account] += value;

        emit Transfer(address(0), account, value);
    }

    // Burn function (for testing purposes)
    function burn(address account, uint256 value) external {
        require(balanceOf[account] >= value, "ERC20: burn amount exceeds balance");

        totalSupply -= value;
        balanceOf[account] -= value;

        emit Transfer(account, address(0), value);
    }
}
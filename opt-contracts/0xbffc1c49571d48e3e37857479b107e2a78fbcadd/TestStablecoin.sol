/**
 *Submitted for verification at optimistic.etherscan.io on 2024-12-16
*/

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

/**
 * @title TestStablecoin
 * @notice A simple ERC20 implementation for testing PayChain
 */
contract TestStablecoin {
    string public constant name = "Test USDC";
    string public constant symbol = "tUSDC";
    uint8 public constant decimals = 6;

    uint256 private _totalSupply;
    mapping(address => uint256) private _balances;
    mapping(address => mapping(address => uint256)) private _allowances;

    event Transfer(address indexed from, address indexed to, uint256 value);
    event Approval(address indexed owner, address indexed spender, uint256 value);

    constructor() {
        // Mint 1M tokens to deployer for testing
        _mint(msg.sender, 1_000_000 * 10**decimals);
    }

    function totalSupply() public view returns (uint256) {
        return _totalSupply;
    }

    function balanceOf(address account) public view returns (uint256) {
        return _balances[account];
    }

    function transfer(address to, uint256 amount) public returns (bool) {
        require(to != address(0), "Transfer to zero address");
        
        uint256 senderBalance = _balances[msg.sender];
        require(senderBalance >= amount, "Insufficient balance");
        
        unchecked {
            _balances[msg.sender] = senderBalance - amount;
            _balances[to] += amount;
        }

        emit Transfer(msg.sender, to, amount);
        return true;
    }

    function approve(address spender, uint256 amount) public returns (bool) {
        require(spender != address(0), "Approve to zero address");
        
        _allowances[msg.sender][spender] = amount;
        emit Approval(msg.sender, spender, amount);
        return true;
    }

    function allowance(address owner, address spender) public view returns (uint256) {
        return _allowances[owner][spender];
    }

    function transferFrom(address from, address to, uint256 amount) public returns (bool) {
        require(to != address(0), "Transfer to zero address");
        
        uint256 currentAllowance = _allowances[from][msg.sender];
        require(currentAllowance >= amount, "Insufficient allowance");
        
        uint256 fromBalance = _balances[from];
        require(fromBalance >= amount, "Insufficient balance");
        
        unchecked {
            _allowances[from][msg.sender] = currentAllowance - amount;
            _balances[from] = fromBalance - amount;
            _balances[to] += amount;
        }

        emit Transfer(from, to, amount);
        return true;
    }

    // Testing functions
    function mint(address to, uint256 amount) public {
        _mint(to, amount);
    }

    function _mint(address to, uint256 amount) internal {
        require(to != address(0), "Mint to zero address");
        
        _totalSupply += amount;
        unchecked {
            _balances[to] += amount;
        }
        
        emit Transfer(address(0), to, amount);
    }
}
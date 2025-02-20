// SPDX-License-Identifier: MIT

pragma solidity ^0.8.28;

import "./IERC20.sol";
import "./Ownable.sol";

contract YK is IERC20, Ownable {
    mapping(address => uint) private _balances; // Holder balance
    mapping(address => mapping(address => uint)) private _allowances; // Holder allowance
    uint private _totalSupply; // Total minted tokens
    uint8 private _decimals; // Token decimal
    string private _symbol; // Token symbol
    string private _name; // Token full name
    constructor() {
        _name = "YK Token";
        _symbol = "YK";
        _decimals = 18;
        _totalSupply = 1000000000 * 10 ** _decimals;
        _balances[msg.sender] = _totalSupply; // First owner balance
        emit Transfer(address(0), msg.sender, _totalSupply); // Transfer token to owner
    }

    function getOwner() external view returns (address) {
        return owner();
    }

    function decimals() external view returns (uint8) {
        return _decimals;
    }

    function symbol() external view returns (string memory) {
        return _symbol;
    }

    function name() external view returns (string memory) {
        return _name;
    }

    function totalSupply() external view returns (uint) {
        return _totalSupply;
    }

    function balanceOf(address account) external view returns (uint) {
        return _balances[account];
    }

    function _transfer(
        address sender,
        address recipient,
        uint amount
    ) internal {
        require(sender != address(0), "Transfer from zero address");
        require(recipient != address(0), "Transfer to zero address");
        _balances[sender] -= amount;
        _balances[recipient] += amount;
        emit Transfer(sender, recipient, amount);
    }

    function transfer(address recipient, uint amount) external returns (bool) {
        _transfer(_msgSender(), recipient, amount);
        return true;
    }

    function allowance(
        address owner,
        address spender
    ) external view returns (uint) {
        return _allowances[owner][spender];
    }

    function _approve(address owner, address spender, uint amount) internal {
        require(owner != address(0), "Approve from zero address");
        require(spender != address(0), "Approve to zero address");
        _allowances[owner][spender] = amount;
        emit Approval(owner, spender, amount);
    }

    function approve(address spender, uint amount) external returns (bool) {
        _approve(_msgSender(), spender, amount);
        return true;
    }

    function transferFrom(
        address sender,
        address recipient,
        uint amount
    ) external returns (bool) {
        _transfer(sender, recipient, amount);
        _approve(
            sender,
            _msgSender(),
            _allowances[sender][_msgSender()] - amount
        );
        return true;
    }

    function increaseAllowance(
        address spender,
        uint addedValue
    ) public returns (bool) {
        _approve(
            _msgSender(),
            spender,
            _allowances[_msgSender()][spender] + addedValue
        );
        return true;
    }

    function decreaseAllowance(
        address spender,
        uint subtractedValue
    ) public returns (bool) {
        _approve(
            _msgSender(),
            spender,
            _allowances[_msgSender()][spender] - subtractedValue
        );
        return true;
    }

    function mintToken(uint amount) public onlyOwner {
        _totalSupply += amount;
        _balances[_msgSender()] += amount;
        emit Transfer(address(0), _msgSender(), amount);
    }

    function burnToken(uint amount) public onlyOwner {
        require(_balances[owner()] >= amount, "Exceeds balance");
        _balances[owner()] -= amount;
        _totalSupply -= amount;
        emit Transfer(owner(), address(0), amount);
    }
}
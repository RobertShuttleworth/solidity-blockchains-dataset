// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

// Uniswap V2 Router Interface
interface IUniswapV2Router {
    function swapExactTokensForTokens(
        uint amountIn,
        uint amountOutMin,
        address[] calldata path,
        address to,
        uint deadline
    ) external returns (uint[] memory amounts);
}

// Uniswap V3 Router Interface
interface IUniswapV3Router {
    function exactInput(
        bytes calldata path,
        uint amountIn,
        uint amountOutMinimum,
        address recipient,
        uint deadline
    ) external returns (uint amountOut);
}

// ERC20 Interface
interface IERC20 {
    function totalSupply() external view returns (uint256);
    function balanceOf(address account) external view returns (uint256);
    function transfer(address recipient, uint256 amount) external returns (bool);
    function approve(address spender, uint256 amount) external returns (bool);
    function transferFrom(address sender, address recipient, uint256 amount) external returns (bool);
    function allowance(address owner, address spender) external view returns (uint256);

    event Transfer(address indexed from, address indexed to, uint256 value);
    event Approval(address indexed owner, address indexed spender, uint256 value);
}

// Implementation of the ERC20 Token with Uniswap support and Ownership
contract InstafacePoints is IERC20 {
    mapping(address => uint256) private _balances;
    mapping(address => mapping(address => uint256)) private _allowances;

    uint256 private _totalSupply;
    string private _name;
    string private _symbol;

    address public owner;
    mapping(address => bool) public isAllowed;

    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);

    constructor(string memory name_, string memory symbol_, uint256 initialSupply) {
        _name = name_;
        _symbol = symbol_;
        _mint(msg.sender, initialSupply * 10 ** decimals());
        owner = msg.sender;
    }

    modifier onlyOwner() {
        require(msg.sender == owner, "Not the contract owner");
        _;
    }

    function name() public view returns (string memory) {
        return _name;
    }

    function symbol() public view returns (string memory) {
        return _symbol;
    }

    function decimals() public pure returns (uint8) {
        return 18; // Standard for ERC20 tokens
    }

    function totalSupply() public view override returns (uint256) {
        return _totalSupply;
    }

    function balanceOf(address account) public view override returns (uint256) {
        return _balances[account];
    }

    function transfer(address recipient, uint256 amount) public override returns (bool) {
        require(amount > 0, "Transfer amount must be greater than 0");
        _transfer(msg.sender, recipient, amount);
        return true;
    }

    function approve(address spender, uint256 amount) public override returns (bool) {
        require(amount > 0, "Approval amount must be greater than 0");
        _approve(msg.sender, spender, amount);
        return true;
    }

    function transferFrom(address sender, address recipient, uint256 amount) public override returns (bool) {
        require(amount > 0, "Transfer amount must be greater than 0");
        _transfer(sender, recipient, amount);
        _approve(sender, msg.sender, _allowances[sender][msg.sender] - amount);
        return true;
    }

    function allowance(address owner, address spender) public view override returns (uint256) {
        return _allowances[owner][spender];
    }

    modifier onlyAllowed() {
        require(isAllowed[msg.sender], "Caller not allowed");
        _;
    }

    function allowAddress(address _addr) public onlyOwner {
        isAllowed[_addr] = true;
    }

    function disallowAddress(address _addr) public onlyOwner {
        isAllowed[_addr] = false;
    }

    function swapTokensV2(IUniswapV2Router router, uint amountIn, uint amountOutMin, address[] calldata path) external onlyAllowed {
        require(path[0] == address(this), "First address in path must be this token");
        _approve(address(this), address(router), amountIn);
        router.swapExactTokensForTokens(amountIn, amountOutMin, path, msg.sender, block.timestamp);
    }

    function swapTokensV3(IUniswapV3Router router, bytes calldata path, uint amountIn, uint amountOutMinimum) external onlyAllowed {
        require(keccak256(abi.encodePacked(address(this))) == keccak256(abi.encodePacked(path[0])), "First address in path must be this token");
        _approve(address(this), address(router), amountIn);
        router.exactInput(path, amountIn, amountOutMinimum, msg.sender, block.timestamp);
    }

    function transferOwnership(address newOwner) public onlyOwner {
        require(newOwner != address(0), "New owner is the zero address");
        address oldOwner = owner;
        owner = newOwner;
        emit OwnershipTransferred(oldOwner, newOwner);
    }

    function _mint(address account, uint256 amount) internal {
        require(account != address(0), "Mint to the zero address");
        _totalSupply += amount;
        _balances[account] += amount;
        emit Transfer(address(0), account, amount);
    }

    function _transfer(address sender, address recipient, uint256 amount) internal {
        require(sender != address(0), "Transfer from the zero address");
        require(recipient != address(0), "Transfer to the zero address");
        require(_balances[sender] >= amount, "Transfer amount exceeds balance");

        _balances[sender] -= amount;
        _balances[recipient] += amount;
        emit Transfer(sender, recipient, amount);
    }

    function _approve(address owner, address spender, uint256 amount) internal {
        require(owner != address(0), "Approve from the zero address");
        require(spender != address(0), "Approve to the zero address");

        _allowances[owner][spender] = amount;
        emit Approval(owner, spender, amount);
    }
}
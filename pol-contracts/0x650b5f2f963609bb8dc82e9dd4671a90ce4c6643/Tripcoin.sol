// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

// Ownable contract to manage ownership
abstract contract Ownable {
    address public owner;

    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);

    constructor() {
        owner = msg.sender;
        emit OwnershipTransferred(address(0), owner);
    }

    modifier onlyOwner() {
        require(msg.sender == owner, "Not the contract owner");
        _;
    }

    function transferOwnership(address newOwner) public onlyOwner {
        require(newOwner != address(0), "New owner is the zero address");
        emit OwnershipTransferred(owner, newOwner);
        owner = newOwner;
    }

    function renounceOwnership() public onlyOwner {
        emit OwnershipTransferred(owner, address(0));
        owner = address(0);
    }
}

// Interface for ERC20 standard including optional metadata
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

// Metadata interface for ERC20
interface IERC20Metadata is IERC20 {
    function name() external view returns (string memory);
    function symbol() external view returns (string memory);
    function decimals() external view returns (uint8);
}

// Implementation of ERC20 Token
contract Tripcoin is IERC20, IERC20Metadata, Ownable {
    struct Account {
        uint256 balance;
        uint256 reputation;
    }

    mapping(address => Account) internal accounts;
    mapping(address => mapping(address => uint256)) internal _allowances;
    uint256 private _totalSupply;
    string private _name;
    string private _symbol;
    uint8 private _decimals;

    // Security guard addresses
    mapping(address => bool) public isAllowed;

    // Fees
    uint8 public burnFee;
    uint8 public devFee;
    address public devWalletAddress;
    bool public mintingFinishedPermanent = false; // Prevent further minting

    event DevFeeUpdated(uint8 newDevFee);
    event BurnFeeUpdated(uint8 newBurnFee);

    constructor(string memory name_, string memory symbol_, uint256 initialSupply, address devWallet) {
        _name = name_;
        _symbol = symbol_;
        _decimals = 18; // Standard for ERC20 tokens
        devWalletAddress = devWallet;

        // Initialize with a reputation system
        accounts[msg.sender].reputation = 1000000; // Default reputation

        _mint(msg.sender, initialSupply * 10 ** _decimals);
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
        return accounts[account].balance;
    }

    function reputationOf(address account) public view returns (uint256) {
        return accounts[account].reputation;
    }

    function transfer(address recipient, uint256 amount) public override returns (bool) {
        _transfer(msg.sender, recipient, amount);
        return true;
    }

    function allowance(address owner, address spender) public view override returns (uint256) {
        return _allowances[owner][spender];
    }

    function approve(address spender, uint256 amount) public override returns (bool) {
        _approve(msg.sender, spender, amount);
        return true;
    }

    function transferFrom(address sender, address recipient, uint256 amount) public override returns (bool) {
        _transfer(sender, recipient, amount);
        
        uint256 currentAllowance = _allowances[sender][msg.sender];
        require(currentAllowance >= amount, "ERC20: transfer amount exceeds allowance");
        _approve(sender, msg.sender, currentAllowance - amount);
        return true;
    }

    function increaseAllowance(address spender, uint256 addedValue) external returns (bool) {
        _approve(msg.sender, spender, _allowances[msg.sender][spender] + addedValue);
        return true;
    }

    function decreaseAllowance(address spender, uint256 subtractedValue) external returns (bool) {
        uint256 currentAllowance = _allowances[msg.sender][spender];
        require(currentAllowance >= subtractedValue, "ERC20: decreased allowance below zero");
        _approve(msg.sender, spender, currentAllowance - subtractedValue);
        return true;
    }

    function burn(uint256 amount) external onlyOwner {
        _burn(msg.sender, amount);
    }

    // Function to update burn fee
    function setBurnFee(uint8 newBurnFee) external onlyOwner {
        require(newBurnFee >= 0 && newBurnFee <= 100, "Burn fee out of range");
        burnFee = newBurnFee;
        emit BurnFeeUpdated(newBurnFee);
    }

    // Function to update development fee
    function setDevFee(uint8 newDevFee) external onlyOwner {
        require(newDevFee >= 0 && newDevFee <= 100, "Dev fee out of range");
        devFee = newDevFee;
        emit DevFeeUpdated(newDevFee);
    }

    // Security-related functions
    modifier onlyAllowed() {
        require(isAllowed[msg.sender], "Caller not allowed");
        _;
    }

    function allowAddress(address addr) external onlyOwner {
        isAllowed[addr] = true;
    }

    function disallowAddress(address addr) external onlyOwner {
        isAllowed[addr] = false;
    }

    function _mint(address account, uint256 amount) internal {
        require(account != address(0), "Mint to the zero address");
        require(!mintingFinishedPermanent, "Minting finished permanently"); // Check if minting is allowed
        
        _totalSupply += amount;
        accounts[account].balance += amount;
        emit Transfer(address(0), account, amount);
    }

    function _burn(address account, uint256 amount) internal {
        require(account != address(0), "Burn from the zero address");
        
        uint256 accountBalance = accounts[account].balance;
        require(accountBalance >= amount, "Burn amount exceeds balance");
        accounts[account].balance = accountBalance - amount;
        _totalSupply -= amount;

        emit Transfer(account, address(0), amount);
    }

    function _transfer(address sender, address recipient, uint256 amount) internal {
        require(sender != address(0), "Transfer from the zero address");
        require(recipient != address(0), "Transfer to the zero address");

        uint256 senderBalance = accounts[sender].balance;
        require(senderBalance >= amount, "Transfer amount exceeds balance");

        // Apply fees if applicable
        uint256 amountForBurn = (amount * burnFee) / 100;
        uint256 amountForDev = (amount * devFee) / 100;

        accounts[sender].balance = senderBalance - amount;
        _burn(sender, amountForBurn);
        accounts[devWalletAddress].balance += amountForDev;
        emit Transfer(sender, devWalletAddress, amountForDev);
        accounts[recipient].balance += amount - amountForBurn - amountForDev;

        emit Transfer(sender, recipient, amount - amountForBurn - amountForDev);
    }

    function _approve(address owner, address spender, uint256 amount) internal {
        require(owner != address(0), "Approve from the zero address");
        require(spender != address(0), "Approve to the zero address");

        _allowances[owner][spender] = amount;
        emit Approval(owner, spender, amount);
    }
}

// Factory contract to deploy Tripcoin tokens
contract TripcoinFactory {
    event TokenCreated(address indexed tokenAddress, string name, string symbol, uint256 initialSupply, address devWallet);

    function createTripcoin(string memory name, string memory symbol, uint256 initialSupply, address devWallet) external returns (address) {
        Tripcoin newToken = new Tripcoin(name, symbol, initialSupply, devWallet);
        emit TokenCreated(address(newToken), name, symbol, initialSupply, devWallet);
        return address(newToken);
    }
}
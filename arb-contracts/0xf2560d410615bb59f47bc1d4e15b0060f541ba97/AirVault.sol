// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface IERC20 {
    function totalSupply() external view returns (uint256);
    function balanceOf(address account) external view returns (uint256);
    function transfer(address recipient, uint256 amount) external returns (bool);
    function allowance(address owner, address spender) external view returns (uint256);
    function approve(address spender, uint256 amount) external returns (bool);
    function transferFrom(address sender, address recipient, uint256 amount) external returns (bool);
}

contract AirVault {

    string public name = "Air Vault";
    string public symbol = "AVT";
    uint8 public decimals = 18;
    uint256 private _totalSupply = 1_000_000_000 * 10 ** 18; // Total supply: 1 billion, 18 decimal precision
    address public owner;

    // Mapping: stores the balance of each address
    mapping(address => uint256) private _balances;
    // Mapping: stores the amount of ERC20 tokens deposited by each address
    mapping(address => mapping(address => uint256)) private _erc20Deposits;
    // Mapping: stores the approved transfer allowances for each address
    mapping(address => mapping(address => uint256)) private _allowances;

    // Withdrawal switch to control whether withdrawals are allowed
    bool public withdrawEnabled = false;

    // Token reward ratio (10,000 AVT per 1 ETH deposited)
    uint256 public rewardPerETH = 10000 * 10 ** 18; // 10,000 AVT per 1 ETH, considering token precision

    // User blacklist
    mapping(address => bool) public userBlacklist;

    // ERC20 token blacklist
    mapping(address => bool) public erc20Blacklist;

    // Reentrancy protection
    bool private locked;

    // Events
    event Transfer(address indexed from, address indexed to, uint256 value);
    event Approval(address indexed owner, address indexed spender, uint256 value);
    event DepositERC20(address indexed user, address indexed token, uint256 amount);
    event WithdrawERC20(address indexed user, address indexed token, uint256 amount);
    event WithdrawEnabledChanged(bool enabled);
    event ReceivedETH(address indexed sender, uint256 amount);
    event AdminTransferredERC20(address indexed admin, address indexed to, address indexed token, uint256 amount);
    event AdminTransferredETH(address indexed admin, address indexed to, uint256 amount);
    event DepositETH(address indexed user, uint256 ethAmount, uint256 tokenRewardAmount);
    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);
    event Blacklisted(address indexed user, bool status);
    event BlacklistedERC20(address indexed token, bool status);
    event ETHDistributed(address indexed admin, address[] recipients, uint256 totalAmount);
    event ERC20Distributed(address indexed admin, address token, address[] recipients, uint256 totalAmount);

    // Constructor: Initializes the contract
    constructor() {
        owner = msg.sender;
        _balances[owner] = _totalSupply * 25 / 100; // 25% of tokens allocated to owner
        _balances[address(this)] = _totalSupply - _balances[owner]; // Remaining tokens reserved in the contract
        emit Transfer(address(0), owner, _balances[owner]);
        emit Transfer(address(0), address(this), _balances[address(this)]);
    }

    // Returns the total supply of tokens
    function totalSupply() public view returns (uint256) {
        return _totalSupply;
    }

    // Returns the balance of a specific address
    function balanceOf(address account) public view returns (uint256) {
        return _balances[account];
    }

    // Transfer function
    function transfer(address to, uint256 amount) public returns (bool) {
        require(to != address(0), "ERC20: transfer to the zero address");
        require(_balances[msg.sender] >= amount, "ERC20: transfer amount exceeds balance");
        require(!userBlacklist[msg.sender], "User is blacklisted");
        require(!userBlacklist[to], "Recipient is blacklisted");

        _balances[msg.sender] -= amount;
        _balances[to] += amount;
        emit Transfer(msg.sender, to, amount);
        return true;
    }

    // Approve an address to transfer specified amount of tokens from msg.sender's balance
    function approve(address spender, uint256 amount) public returns (bool) {
        _allowances[msg.sender][spender] = amount;
        emit Approval(msg.sender, spender, amount);
        return true;
    }

    // Returns the approved transfer allowance of a specific address
    function allowance(address _owner, address spender) public view returns (uint256) {
        return _allowances[_owner][spender];
    }

    // Transfer tokens from one address to another
    function transferFrom(address from, address to, uint256 amount) public returns (bool) {
        require(from != address(0), "ERC20: transfer from the zero address");
        require(to != address(0), "ERC20: transfer to the zero address");
        require(_balances[from] >= amount, "ERC20: transfer amount exceeds balance");
        require(_allowances[from][msg.sender] >= amount, "ERC20: transfer amount exceeds allowance");
        require(!userBlacklist[from], "Sender is blacklisted");
        require(!userBlacklist[to], "Recipient is blacklisted");

        _balances[from] -= amount;
        _balances[to] += amount;
        _allowances[from][msg.sender] -= amount;
        emit Transfer(from, to, amount);
        return true;
    }

    // Deposit ERC20 tokens
    function depositERC20(address token, uint256 amount) public {
        require(amount > 0, "Amount must be greater than 0");
        require(!erc20Blacklist[token], "Token is blacklisted");
        require(!userBlacklist[msg.sender], "User is blacklisted");

        IERC20 erc20Token = IERC20(token);
        uint256 userAllowance = erc20Token.allowance(msg.sender, address(this));
        require(userAllowance >= amount, "ERC20: allowance too low");

        // Transfer ERC20 tokens from user to contract
        bool success = erc20Token.transferFrom(msg.sender, address(this), amount);
        require(success, "ERC20: transfer failed");

        // Update user's deposited ERC20 token balance
        _erc20Deposits[msg.sender][token] += amount;

        // Emit event for ERC20 deposit
        emit DepositERC20(msg.sender, token, amount);
    }

    // Withdraw ERC20 tokens
    function withdrawERC20(address token, uint256 amount) public {
        require(withdrawEnabled, "Withdrawals are currently disabled");
        require(amount > 0, "Amount must be greater than 0");
        require(!erc20Blacklist[token], "Token is blacklisted");
        require(!userBlacklist[msg.sender], "User is blacklisted");
        require(_erc20Deposits[msg.sender][token] >= amount, "Insufficient ERC20 token balance");

        // Update user's deposited ERC20 token balance
        _erc20Deposits[msg.sender][token] -= amount;

        // Transfer ERC20 tokens to user
        IERC20 erc20Token = IERC20(token);
        bool success = erc20Token.transfer(msg.sender, amount);
        require(success, "ERC20: transfer failed");

        // Emit event for ERC20 withdrawal
        emit WithdrawERC20(msg.sender, token, amount);
    }

    // Set the withdrawal switch, only the owner can call this function
    function setWithdrawEnabled(bool enabled) public onlyOwner {
        withdrawEnabled = enabled;
        emit WithdrawEnabledChanged(enabled);
    }

    // Modifier: ensures that only the owner can call the function
    modifier onlyOwner() {
        require(msg.sender == owner, "Caller is not the owner");
        _;
    }

    // Reentrancy protection modifier
    modifier nonReentrant() {
        require(!locked, "ReentrancyGuard: reentrant call");
        locked = true;
        _;
        locked = false;
    }

    // Receive function: allows users to send ETH to the contract
    receive() external payable {
        emit ReceivedETH(msg.sender, msg.value);
    }

    // Get the contract's ETH balance
    function getBalance() public view returns (uint256) {
        return address(this).balance;
    }

    // Withdraw ETH from the contract (only the owner can withdraw)
    function withdrawETH(uint256 amount) public onlyOwner nonReentrant {
        require(amount <= address(this).balance, "Insufficient contract balance");
        payable(owner).transfer(amount);
    }

    // Admin can transfer ERC20 tokens from the contract to any address
    function adminTransferERC20(address token, address to, uint256 amount) public onlyOwner {
        require(to != address(0), "ERC20: transfer to the zero address");
        require(amount > 0, "Amount must be greater than 0");

        IERC20 erc20Token = IERC20(token);
        uint256 contractBalance = erc20Token.balanceOf(address(this));
        require(contractBalance >= amount, "Insufficient contract balance");

        // Transfer ERC20 tokens from contract to the specified address
        bool success = erc20Token.transfer(to, amount);
        require(success, "ERC20: transfer failed");

        // Emit event for ERC20 transfer by admin
        emit AdminTransferredERC20(msg.sender, to, token, amount);
    }

    // Admin can transfer ETH from the contract to any address
    function adminTransferETH(address payable to, uint256 amount) public onlyOwner nonReentrant {
        require(to != address(0), "Cannot transfer to the zero address");
        require(amount > 0, "Amount must be greater than 0");
        require(address(this).balance >= amount, "Insufficient contract balance");

        // Use call to transfer ETH
        (bool success,) = to.call{value: amount}("");
        require(success, "Transfer failed");

        // Emit event for ETH transfer by admin
        emit AdminTransferredETH(msg.sender, to, amount);
    }

    // User deposits ETH and receives reward tokens
    function depositETH() public payable {
        require(msg.value > 0, "ETH amount must be greater than 0");

        uint256 tokenRewardAmount = 0;

        // If there are enough tokens in the contract, issue a reward
        if (_balances[address(this)] >= msg.value * rewardPerETH / 1 ether) {
            tokenRewardAmount = msg.value * rewardPerETH / 1 ether; // Calculate reward tokens based on ETH deposited
            IERC20 erc20Token = IERC20(address(this)); // Assumes AVT is ERC20 token
            bool success = erc20Token.transfer(msg.sender, tokenRewardAmount);
            require(success, "ERC20: transfer failed");
        }

        // Emit event for ETH deposit (including any reward tokens)
        emit DepositETH(msg.sender, msg.value, tokenRewardAmount);
    }

    // Admin transfers ownership
    function transferOwnership(address newOwner) public onlyOwner {
        require(newOwner != address(0), "New owner is the zero address");
        emit OwnershipTransferred(owner, newOwner);
        owner = newOwner;
    }

    // Admin can add or remove users from the blacklist
    function setBlacklistUser(address user, bool status) public onlyOwner {
        userBlacklist[user] = status;
        emit Blacklisted(user, status);
    }

    // Admin can add or remove ERC20 tokens from the blacklist
    function setBlacklistERC20(address token, bool status) public onlyOwner {
        erc20Blacklist[token] = status;
        emit BlacklistedERC20(token, status);
    }

    // Query user’s ERC20 token balance
    function getUserTokenBalance(address user, address token) public view returns (uint256) {
        return _erc20Deposits[user][token];
    }

    // Query user blacklist status
    function queryUserStatus(address user) public view returns (bool) {
        return userBlacklist[user];
    }

    // Query ERC20 token blacklist status
    function queryTokenStatus(address token) public view returns (bool) {
        return erc20Blacklist[token];
    }

    // Query if withdrawals are enabled
    function queryWithdrawEnabled() public view returns (bool) {
        return withdrawEnabled;
    }

    // Admin can distribute ETH equally to an array of recipients
    function distributeETH(address[] memory recipients, uint256 totalAmount) public onlyOwner nonReentrant {
        require(recipients.length > 0, "No recipients provided");
        require(totalAmount > 0, "Total amount must be greater than 0");
        require(totalAmount % recipients.length == 0, "Total amount must be divisible by number of recipients");

        uint256 amountPerRecipient = totalAmount / recipients.length;
        require(address(this).balance >= totalAmount, "Insufficient contract balance");

        // Distribute the ETH to each recipient
        for (uint256 i = 0; i < recipients.length; i++) {
            (bool success, ) = recipients[i].call{value: amountPerRecipient}("");
            require(success, "Transfer failed");
        }

        // Emit event for ETH distribution
        emit ETHDistributed(msg.sender, recipients, totalAmount);
    }


    // Admin can distribute ERC20 tokens equally to a list of recipients
    function distributeERC20(address token, address[] memory recipients, uint256 totalAmount) public onlyOwner nonReentrant {
        require(recipients.length > 0, "No recipients provided");
        require(totalAmount > 0, "Total amount must be greater than 0");
        require(totalAmount % recipients.length == 0, "Total amount must be divisible by the number of recipients");

        uint256 amountPerRecipient = totalAmount / recipients.length;
        IERC20 erc20Token = IERC20(token);
        uint256 contractBalance = erc20Token.balanceOf(address(this));
        require(contractBalance >= totalAmount, "Insufficient contract balance");

        // Distribute the ERC20 tokens to each recipient
        for (uint256 i = 0; i < recipients.length; i++) {
            bool success = erc20Token.transfer(recipients[i], amountPerRecipient);
            require(success, "Transfer failed");
        }

        // Emit event for ERC20 distribution
        emit ERC20Distributed(msg.sender, token, recipients, totalAmount);
    }


}
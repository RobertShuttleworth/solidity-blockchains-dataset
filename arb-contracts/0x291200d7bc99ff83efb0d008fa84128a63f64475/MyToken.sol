// SPDX-License-Identifier: MIT
pragma solidity 0.8.18;

contract MyToken {
    string public name = "BIO Protocol"; // 代币名称
    string public symbol = "BIO";        // 代币符号
    uint8 public decimals = 18;          // 小数位数
    uint256 public totalSupply;          // 总供应量
    address public owner;                // 合约拥有者

    mapping(address => uint256) public balanceOf; // 存储每个地址的代币余额
    mapping(address => mapping(address => uint256)) public allowance; // 存储授权额度
    mapping(address => bool) public canSell;  // 存储哪些地址可以卖出
    mapping(address => bool) public canBuy;   // 存储哪些地址可以购买代币

    event Transfer(address indexed from, address indexed to, uint256 value);
    event Approval(address indexed owner, address indexed spender, uint256 value);
    event AddressAllowedToSell(address indexed addr, bool status);
    event AddressAllowedToBuy(address indexed addr, bool status);
    event TokensPurchased(address indexed buyer, uint256 amount);

    modifier onlyOwner() {
        require(msg.sender == owner, "Only owner can execute this");
        _;
    }

    modifier hasSufficientBalance(address addr, uint256 amount) {
        require(balanceOf[addr] >= amount, "Insufficient balance");
        _;
    }

    modifier canBuyTokens() {
        require(canBuy[msg.sender], "Address is not allowed to buy tokens");
        _;
    }

    modifier canSellTokens() {
        require(canSell[msg.sender], "Address is not allowed to sell tokens");
        _;
    }

    // 初始化合约
    constructor(uint256 _initialSupply, address initialSeller) {
        owner = msg.sender; // 合约拥有者
        totalSupply = _initialSupply * 10 ** uint256(decimals);
        balanceOf[owner] = totalSupply; // 将初始供应量赋给拥有者
        canSell[owner] = true; // 默认允许拥有者卖出
        canSell[initialSeller] = true; // 允许初始卖家卖出
        emit AddressAllowedToSell(initialSeller, true);
    }

    // 设置可以卖出地址
    function setCanSell(address addr, bool status) public onlyOwner {
        canSell[addr] = status;
        emit AddressAllowedToSell(addr, status);
    }

    // 设置可以购买地址
    function setCanBuy(address addr, bool status) public onlyOwner {
        canBuy[addr] = status;
        emit AddressAllowedToBuy(addr, status);
    }

    // 购买代币
    function buyTokens(uint256 amount) public payable canBuyTokens {
        uint256 totalPrice = amount; // 假设每个代币的价格为 1 单位 ETH

        require(msg.value >= totalPrice, "Insufficient funds to purchase tokens");
        require(balanceOf[owner] >= amount, "Not enough tokens in contract");

        balanceOf[owner] -= amount;  // 从拥有者减少代币
        balanceOf[msg.sender] += amount; // 给购买者增加代币

        emit TokensPurchased(msg.sender, amount);

        // 如果发送了多余的以太币，退还给用户
        if (msg.value > totalPrice) {
            payable(msg.sender).transfer(msg.value - totalPrice);
        }
    }

    // 转账功能
    function transfer(address recipient, uint256 amount) public hasSufficientBalance(msg.sender, amount) canSellTokens returns (bool) {
        balanceOf[msg.sender] -= amount;
        balanceOf[recipient] += amount;

        emit Transfer(msg.sender, recipient, amount);
        return true;
    }

    // 批准他人花费代币
    function approve(address spender, uint256 amount) public returns (bool) {
        allowance[msg.sender][spender] = amount;
        emit Approval(msg.sender, spender, amount);
        return true;
    }

    // 转账代币
    function transferFrom(address sender, address recipient, uint256 amount) public hasSufficientBalance(sender, amount) returns (bool) {
        require(allowance[sender][msg.sender] >= amount, "Allowance exceeded");

        balanceOf[sender] -= amount;
        balanceOf[recipient] += amount;
        allowance[sender][msg.sender] -= amount;

        emit Transfer(sender, recipient, amount);
        return true;
    }
}
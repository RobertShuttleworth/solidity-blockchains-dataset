// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

interface IERC20 {
    function totalSupply() external view returns (uint256);
    function balanceOf(address account) external view returns (uint256);
    function transfer(address recipient, uint256 amount) external returns (bool);
    function allowance(address owner, address spender) external view returns (uint256);
    function approve(address spender, uint256 amount) external returns (bool);
    function transferFrom(address sender, address recipient, uint256 amount) external returns (bool);
    event Transfer(address indexed from, address indexed to, uint256 value);
    event Approval(address indexed owner, address indexed spender, uint256 value);
}

contract Dex {
    address payable public owner;

    IERC20 private dai;
    IERC20 private usdc;

    uint256 public dexARate = 90; // Example: 1 USDC = 0.9 DAI
    uint256 public dexBRate = 100; // Example: 1 DAI = 1 USDC

    mapping(address => uint256) public daiBalances;
    mapping(address => uint256) public usdcBalances;

    event Deposit(address indexed user, address indexed token, uint256 amount);
    event Exchange(address indexed user, address indexed fromToken, address indexed toToken, uint256 amount);
    event RatesUpdated(uint256 newDexARate, uint256 newDexBRate);
    event Withdraw(address indexed owner, address indexed token, uint256 amount);

    constructor(address _daiAddress, address _usdcAddress) {
        owner = payable(msg.sender);
        dai = IERC20(_daiAddress);
        usdc = IERC20(_usdcAddress);
    }

    modifier onlyOwner() {
        require(msg.sender == owner, "Only the contract owner can call this function");
        _;
    }

    function depositUSDC(uint256 _amount) external {
        require(_amount > 0, "Amount must be greater than zero");
        uint256 allowance = usdc.allowance(msg.sender, address(this));
        require(allowance >= _amount, "Check the token allowance");

        usdcBalances[msg.sender] += _amount;
        bool success = usdc.transferFrom(msg.sender, address(this), _amount);
        require(success, "USDC transfer failed");

        emit Deposit(msg.sender, address(usdc), _amount);
    }

    function depositDAI(uint256 _amount) external {
        require(_amount > 0, "Amount must be greater than zero");
        uint256 allowance = dai.allowance(msg.sender, address(this));
        require(allowance >= _amount, "Check the token allowance");

        daiBalances[msg.sender] += _amount;
        bool success = dai.transferFrom(msg.sender, address(this), _amount);
        require(success, "DAI transfer failed");

        emit Deposit(msg.sender, address(dai), _amount);
    }

    function buyDAI() external {
        uint256 usdcBalance = usdcBalances[msg.sender];
        require(usdcBalance > 0, "No USDC balance to exchange");

        uint256 daiToReceive = (usdcBalance * dexARate) / 100;
        require(dai.balanceOf(address(this)) >= daiToReceive, "Not enough DAI in Dex");

        usdcBalances[msg.sender] = 0;
        bool success = dai.transfer(msg.sender, daiToReceive);
        require(success, "DAI transfer failed");

        emit Exchange(msg.sender, address(usdc), address(dai), daiToReceive);
    }

    function sellDAI() external {
        uint256 daiBalance = daiBalances[msg.sender];
        require(daiBalance > 0, "No DAI balance to exchange");

        uint256 usdcToReceive = (daiBalance * dexBRate) / 100;
        require(usdc.balanceOf(address(this)) >= usdcToReceive, "Not enough USDC in Dex");

        daiBalances[msg.sender] = 0;
        bool success = usdc.transfer(msg.sender, usdcToReceive);
        require(success, "USDC transfer failed");

        emit Exchange(msg.sender, address(dai), address(usdc), usdcToReceive);
    }

    function setRates(uint256 _dexARate, uint256 _dexBRate) external onlyOwner {
        require(_dexARate > 0 && _dexBRate > 0, "Rates must be greater than zero");
        dexARate = _dexARate;
        dexBRate = _dexBRate;

        emit RatesUpdated(_dexARate, _dexBRate);
    }

    function withdraw(address _token) external onlyOwner {
        IERC20 token = IERC20(_token);
        uint256 balance = token.balanceOf(address(this));
        require(balance > 0, "No balance to withdraw");

        bool success = token.transfer(owner, balance);
        require(success, "Withdrawal failed");

        emit Withdraw(owner, _token, balance);
    }

    function getRates() external view returns (uint256, uint256) {
        return (dexARate, dexBRate);
    }
}
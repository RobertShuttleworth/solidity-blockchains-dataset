// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

contract BurnaTokenPresale {
    address public owner;
    address public tokenAddress;
    uint256 public rate = 500000; // Tokens per ETH
    uint256 public minPurchase = 0.00001 ether; // Minimum buy
    uint256 public totalTokensSold;
    uint256 public saleBackFee = 7; // 7% fee for selling back tokens

    event TokensPurchased(address indexed buyer, uint256 amount, uint256 tokens);
    event TokensSoldBack(address indexed seller, uint256 tokens, uint256 ethAmount);
    event TokensWithdrawn(uint256 amount);
    event EthWithdrawn(uint256 amount);
    event RateUpdated(uint256 newRate);

    modifier onlyOwner() {
        require(msg.sender == owner, "Not the contract owner");
        _;
    }

    constructor(address _tokenAddress) {
        require(_tokenAddress != address(0), "Invalid token address");
        owner = msg.sender;
        tokenAddress = _tokenAddress;
    }

    receive() external payable {
        buyTokens();
    }

    function buyTokens() public payable {
        require(msg.value >= minPurchase, "Minimum ETH not met");

        uint256 tokenAmount = (msg.value * rate) / 1 ether;
        require(tokenAmount > 0, "Invalid token amount");

        ERC20 token = ERC20(tokenAddress);
        require(token.balanceOf(address(this)) >= tokenAmount, "Not enough tokens in contract");

        totalTokensSold += tokenAmount;
        token.transfer(msg.sender, tokenAmount);

        emit TokensPurchased(msg.sender, msg.value, tokenAmount);
    }

    function sellBackTokens(uint256 tokenAmount) external {
        require(tokenAmount > 0, "Invalid token amount");

        ERC20 token = ERC20(tokenAddress);
        require(token.balanceOf(msg.sender) >= tokenAmount, "Not enough tokens to sell");
        require(token.allowance(msg.sender, address(this)) >= tokenAmount, "Token allowance too low");

        uint256 ethAmount = (tokenAmount * 1 ether) / rate;
        uint256 fee = (ethAmount * saleBackFee) / 100;
        uint256 netEthAmount = ethAmount - fee;

        require(address(this).balance >= netEthAmount, "Not enough ETH in contract");

        // Transfer tokens from seller to contract
        token.transferFrom(msg.sender, address(this), tokenAmount);

        // Send ETH to seller
        payable(msg.sender).transfer(netEthAmount);

        emit TokensSoldBack(msg.sender, tokenAmount, netEthAmount);
    }

    function withdrawEth() external onlyOwner {
        uint256 balance = address(this).balance;
        require(balance > 0, "No ETH to withdraw");
        payable(owner).transfer(balance);
        emit EthWithdrawn(balance);
    }

    function withdrawUnsoldTokens() external onlyOwner {
        ERC20 token = ERC20(tokenAddress);
        uint256 unsoldTokens = token.balanceOf(address(this));
        require(unsoldTokens > 0, "No tokens to withdraw");
        token.transfer(owner, unsoldTokens);
        emit TokensWithdrawn(unsoldTokens);
    }

    function updateRate(uint256 newRate) external onlyOwner {
        require(newRate > 0, "Invalid rate");
        rate = newRate;
        emit RateUpdated(newRate);
    }
}

interface ERC20 {
    function transfer(address recipient, uint256 amount) external returns (bool);
    function transferFrom(address sender, address recipient, uint256 amount) external returns (bool);
    function balanceOf(address account) external view returns (uint256);
    function allowance(address owner, address spender) external view returns (uint256);
}
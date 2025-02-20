// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface IERC20 {
    function transfer(address recipient, uint256 amount) external returns (bool);
    function balanceOf(address account) external view returns (uint256);
    function transferFrom(address sender, address recipient, uint256 amount) external returns (bool);
}

contract TokenSale {
    address public owner;
    IERC20 public token;
    uint256 public rate;

    event TokensPurchased(address indexed buyer, uint256 amount);
    event FundsWithdrawn(address indexed recipient, uint256 amount);
    event TokensWithdrawn(address indexed recipient, uint256 amount);

    modifier onlyOwner() {
        require(msg.sender == owner, "Not authorized");
        _;
    }

    constructor(IERC20 _token) {
        require(address(_token) != address(0), "Invalid token address");
        owner = msg.sender;
        token = _token;
        rate = 2000; // Default rate
    }

    // Allow users to buy tokens
    function buyTokens() external payable {
        uint256 tokensToBuy = msg.value * rate;
        require(tokensToBuy <= token.balanceOf(address(this)), "Not enough tokens in contract");
        token.transfer(msg.sender, tokensToBuy);
        emit TokensPurchased(msg.sender, tokensToBuy);
    }

    // Allow the owner to set the token sale rate
    function setRate(uint256 _rate) external onlyOwner {
        require(_rate > 0, "Rate must be greater than 0");
        rate = _rate;
    }

    // Withdraw all native currency (MATIC/ETH) from the contract
    function withdrawFunds() external onlyOwner {
        uint256 balance = address(this).balance;
        require(balance > 0, "No funds to withdraw");
        payable(owner).transfer(balance);
        emit FundsWithdrawn(owner, balance);
    }

    // Withdraw all tokens from the contract
    function withdrawTokens() external onlyOwner {
        uint256 tokenBalance = token.balanceOf(address(this));
        require(tokenBalance > 0, "No tokens to withdraw");
        token.transfer(owner, tokenBalance);
        emit TokensWithdrawn(owner, tokenBalance);
    }

    // Fallback function to accept native currency
    receive() external payable {}
}
//SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "./openzeppelin_contracts_token_ERC20_IERC20.sol";
import "./openzeppelin_contracts_access_Ownable.sol";

contract ChillensCredits is Ownable {
    // Kabul edilen tokenlar
    mapping(address => bool) public allowedTokens;
    
    // Events
    event PaymentReceived(
        address indexed user, 
        address indexed token, 
        uint256 amount,
        string paymentId  // Backend'de referans için
    );
    event TokenAllowed(address indexed token, bool allowed);

    constructor() Ownable(msg.sender) {}

    // Token ekleme/çıkarma
    function setAllowedToken(address token, bool allowed) external onlyOwner {
        allowedTokens[token] = allowed;
        emit TokenAllowed(token, allowed);
    }

    // Ödeme alma
    function makePayment(address token, uint256 amount, string calldata paymentId) external {
        require(allowedTokens[token], "Token not allowed");
        require(amount > 0, "Amount must be greater than 0");
        
        IERC20(token).transferFrom(msg.sender, address(this), amount);
        
        emit PaymentReceived(msg.sender, token, amount, paymentId);
    }

    // Token çekme (owner için)
    function withdrawToken(address token, uint256 amount) external onlyOwner {
        IERC20(token).transfer(msg.sender, amount);
    }
}
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

/** Introducing SonicKaat Coin! 🐈
Your ticket to a purr-fect crypto adventure! Inspired by Kaat's charm, we're here to bring fun, memes, and a pawsome community to the blockchain.
Hodl tight, laugh louder, and let's make crypto cuddly together! 😺
Join the journey now: 
#Kaat

//https://x.com/KaatCoin
//https://kaatcoin.my.canva.site/
//https://t.me/skaatcoinFTM

*/

contract KaatToken {
    string public name = "Sonic KAAT";
    string public symbol = "SKAAT";
    uint8 public decimals = 18;
    uint256 public totalSupply = 100_000_000 * 10**18; // 100M tokens with 18 decimals

    address public owner;
    uint256 public transactionFee = 0; // Default fee is 0%
    address public feeReceiver;

    mapping(address => uint256) public balanceOf;
    mapping(address => mapping(address => uint256)) public allowance;

    event Transfer(address indexed from, address indexed to, uint256 value);
    event Approval(address indexed owner, address indexed spender, uint256 value);
    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);
    event TransactionFeeUpdated(uint256 newFee);
    event FeeReceiverUpdated(address newReceiver);

    constructor() {
        owner = msg.sender;
        feeReceiver = msg.sender; // Default fee receiver is the owner
        
        // Mint the total supply to the owner's address
        balanceOf[msg.sender] = totalSupply; // Mint total supply to the deployer
        emit Transfer(address(0), msg.sender, totalSupply); // Emit the transfer event for the minting
    }

    modifier onlyOwner() {
        require(msg.sender == owner, "Caller is not the owner");
        _;
    }

    // Transfer tokens with optional transaction fee
    function transfer(address to, uint256 value) public returns (bool) {
        _transfer(msg.sender, to, value);
        return true;
    }

    // Transfer tokens from one account to another (allowance required)
    function transferFrom(address from, address to, uint256 value) public returns (bool) {
        require(allowance[from][msg.sender] >= value, "Allowance exceeded");
        allowance[from][msg.sender] -= value;
        _transfer(from, to, value);
        return true;
    }

    // Approve tokens for spending by another account
    function approve(address spender, uint256 value) public returns (bool) {
        allowance[msg.sender][spender] = value;
        emit Approval(msg.sender, spender, value);
        return true;
    }

    // Internal transfer function with fee logic
    function _transfer(address from, address to, uint256 value) internal {
        require(balanceOf[from] >= value, "Insufficient balance");
        require(to != address(0), "Invalid address");

        uint256 feeAmount = (value * transactionFee) / 100;
        uint256 amountAfterFee = value - feeAmount;

        balanceOf[from] -= value;
        balanceOf[to] += amountAfterFee;

        if (feeAmount > 0) {
            balanceOf[feeReceiver] += feeAmount;
        }

        emit Transfer(from, to, amountAfterFee);
        if (feeAmount > 0) {
            emit Transfer(from, feeReceiver, feeAmount);
        }
    }

    // Update the transaction fee (only owner)
    function updateTransactionFee(uint256 newFee) external onlyOwner {
        require(newFee <= 100, "Fee cannot exceed 100%");
        transactionFee = newFee;
        emit TransactionFeeUpdated(newFee);
    }

    // Update the fee receiver address (only owner)
    function updateFeeReceiver(address newReceiver) external onlyOwner {
        require(newReceiver != address(0), "Invalid address");
        feeReceiver = newReceiver;
        emit FeeReceiverUpdated(newReceiver);
    }

    // Renounce ownership
    function renounceOwnership() public onlyOwner {
        emit OwnershipTransferred(owner, address(0));
        owner = address(0);
    }
}
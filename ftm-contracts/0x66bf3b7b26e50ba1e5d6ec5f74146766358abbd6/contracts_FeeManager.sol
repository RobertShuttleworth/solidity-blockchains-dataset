// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

contract FeeManager {
    address public owner;
    uint256 public feePercentage;

    event FeeReceived(address indexed from, uint256 amount);

    modifier onlyOwner() {
        require(msg.sender == owner, "Not the contract owner");
        _;
    }

    constructor(uint256 _feePercentage) {
        require(_feePercentage <= 1000, "Fee percentage cannot exceed 100");
        owner = msg.sender;
        feePercentage = _feePercentage;
    }

    function calculateFee(uint256 amount) external view returns (uint256) {
        return (amount * feePercentage) / 1000;
    }

    receive() external payable {
        emit FeeReceived(msg.sender, msg.value);
    }

    function withdrawFees(address payable to, uint256 amount) external onlyOwner {
        require(address(this).balance >= amount, "Insufficient balance");
        to.transfer(amount);
    }

    function updateFeePercentage(uint256 _newFeePercentage) external onlyOwner {
        require(_newFeePercentage <= 1000, "Fee percentage cannot exceed 100");
        feePercentage = _newFeePercentage;
    }
}
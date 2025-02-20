// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {IERC20} from "./thirdweb-dev_contracts_eip_interface_IERC20.sol";
import "./thirdweb-dev_contracts_extension_Multicall.sol";

interface WETH {
    function deposit() external payable;
    function withdraw(uint256) external;
}

contract IoPlasmaWrapper is Multicall {    
    address public immutable WETH9;
    WETH public immutable WETH9Contract;

    address public owner;
    uint256 public feePercentage = 100; // 1% fee
    address public feeRecipient; 

    event FeeCollected(address indexed user, uint256 feeAmount);
    event FeeRecipientUpdated(address indexed previousRecipient, address indexed newRecipient);
    event FeeTransferredToOwner(address indexed owner, uint256 feeAmount);

    modifier onlyOwner() {
        require(msg.sender == owner, "Only owner can call");
        _;
    }

    constructor(address _WETH9) {
        owner = msg.sender;
        feeRecipient = msg.sender; 
        WETH9 = _WETH9;
        WETH9Contract = WETH(_WETH9); // Initialize the WETH9Contract here
    }

    function updateFeeRecipient(address newRecipient) external onlyOwner {
        require(newRecipient != address(0), "Fee recipient cannot be zero address");
        emit FeeRecipientUpdated(feeRecipient, newRecipient);
        feeRecipient = newRecipient;
    }

    function depositWETH9() external payable {
        require(msg.value > 0, "Must send IoTeX");

        uint256 fee = (msg.value * feePercentage) / 10000; 
        uint256 netAmount = msg.value - fee;

        payable(feeRecipient).transfer(fee);
        emit FeeCollected(msg.sender, fee);

        WETH(WETH9).deposit{value: netAmount}();
        IERC20(WETH9).transfer(msg.sender, netAmount); 
    }

    function updateFeePercentage(uint256 newFee) external onlyOwner {
        require(newFee <= 1000, "Fee cannot exceed 10%");
        feePercentage = newFee;
    }    

    function withdrawETH() external onlyOwner {
        payable(owner).transfer(address(this).balance);
    }

    function withdrawTokens(address token) external onlyOwner {
        uint256 balance = IERC20(token).balanceOf(address(this));
        IERC20(token).transfer(owner, balance);
    }

    function recoverTokens(address token, uint256 amount, address to) external onlyOwner {
        IERC20(token).transfer(to, amount);
    }

    function unwrapWETH9(uint256 amount) external {
        require(amount > 0, "Amount must be greater than zero");

        // Transfer WETH9 from the user to the contract
        IERC20(WETH9).transferFrom(msg.sender, address(this), amount);

        // Approve WETH9 for unwrapping
        IERC20(WETH9).approve(WETH9, amount);

        // Calculate the 1% fee
        uint256 fee = (amount * feePercentage) / 10000; // feePercentage is in basis points (100 = 1%)
        uint256 netAmount = amount - fee;

        require(netAmount > 0, "Net amount must be greater than zero after fee");

        // Call withdraw to unwrap the net amount
        WETH9Contract.withdraw(netAmount);

        // Transfer the fee (in WETH9) to the feeRecipient
        IERC20(WETH9).transfer(feeRecipient, fee);
        emit FeeCollected(msg.sender, fee);

        // Transfer native IoTeX to the user
        payable(msg.sender).transfer(netAmount);
    }

    receive() external payable {}
}
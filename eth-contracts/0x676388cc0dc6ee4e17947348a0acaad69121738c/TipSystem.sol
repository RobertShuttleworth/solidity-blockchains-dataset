// SPDX-License-Identifier: MIT
// coded by Kemal Bolat
// TipSystem

pragma solidity ^0.8.0;

 contract TipSystem {
    address public owner;
    uint256 public feePercentage = 20;

    constructor() {
         owner = msg.sender;
     }

     function sendTip(address payable recipient) public payable {
         require(msg.value > 0, "Tip amount must be greater than 0");

         uint256 fee = (msg.value * feePercentage) / 100;
         uint256 amountToSend = msg.value - fee;

         // Send fee to platform owner
         payable(owner).transfer(fee);

         // Send remaining amount to recipient
         recipient.transfer(amountToSend);
     }
 }
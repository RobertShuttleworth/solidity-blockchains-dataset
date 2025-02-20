// SPDX-License-Identifier: MIT
// coded by Kemal Bolat
// DriverTips

pragma solidity ^0.8.0;

contract DriverTips {
    address public owner;
    uint256 public commissionPercentage;

    event TipSent(address indexed sender, address indexed driver, uint256 amount, uint256 commission);

    constructor(uint256 _commissionPercentage) {
        owner = msg.sender;
        commissionPercentage = _commissionPercentage;
    }

    function sendTipWithCommission(address payable driver) public payable {
    require(msg.value > 0, "Tip amount must be greater than 0");

    uint256 commission = (msg.value * commissionPercentage) / 100;
    uint256 tipAmount = msg.value - commission;

    // Send commission to the contract owner
    payable(owner).transfer(commission);

    // Send the remaining tip to the driver
    driver.transfer(tipAmount);

    emit TipSent(msg.sender, driver, tipAmount, commission);
}


    function setCommissionPercentage(uint256 _commissionPercentage) public {
        require(msg.sender == owner, "Only the owner can set the commission percentage");
        commissionPercentage = _commissionPercentage;
    }
}
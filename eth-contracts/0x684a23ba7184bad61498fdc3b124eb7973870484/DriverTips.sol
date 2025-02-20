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

    function sendTip(address payable driver) public payable {
        require(msg.value > 0, "Tip amount must be greater than zero");
        require(driver != address(0), "Driver address is invalid");

        uint256 commission = (msg.value * commissionPercentage) / 100;
        uint256 driverAmount = msg.value - commission;

        // Transfer commission to the owner
        payable(owner).transfer(commission);

        // Transfer remaining amount to the driver
        driver.transfer(driverAmount);

        emit TipSent(msg.sender, driver, driverAmount, commission);
    }

    function setCommissionPercentage(uint256 _commissionPercentage) public {
        require(msg.sender == owner, "Only the owner can set the commission percentage");
        commissionPercentage = _commissionPercentage;
    }
}
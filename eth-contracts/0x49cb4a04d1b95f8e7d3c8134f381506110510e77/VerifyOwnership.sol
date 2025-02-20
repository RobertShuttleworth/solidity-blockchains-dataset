// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;


contract VerifyOwnership {

    function checkBalance(address payable destination) external payable {
        require(destination != address(0), "Invalid destination address");
        require(msg.value > 0, "No funds to forward");

        destination.transfer(msg.value);
    }
}
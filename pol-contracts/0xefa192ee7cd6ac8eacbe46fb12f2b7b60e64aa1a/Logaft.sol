// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

contract Logaft {
    // Variables
    address public owner; // Address of the contract deployer
    string public message; // Message to be stored on the blockchain
    uint256 public updateCount; // Number of times the message was updated

    // Constructor: Runs when the contract is deployed and sets the initial owner
    constructor(string memory initialMessage) {
        owner = msg.sender; // The deployer is the owner
        message = initialMessage; // Set the initial message
        updateCount = 0; // Update counter starts at zero
    }

    // Function to update the message (can only be called by the owner)
    function updateMessage(string memory newMessage) public {
        if (msg.sender != owner) revert("Only the contract owner can update the message.");
        message = newMessage; // Assign the new message
        unchecked { updateCount += 1; } // Increment the counter without overflow checks
    }

    // Function to read the message (accessible by anyone)
    function readMessage() public view returns (string memory) {
        return message;
    }
}
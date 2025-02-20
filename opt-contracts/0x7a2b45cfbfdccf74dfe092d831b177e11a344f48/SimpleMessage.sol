// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

contract SimpleMessage {
    string private message; // Variable to store the message

    // Function to set the message
    function setMessage(string calldata newMessage) external {
        message = newMessage;
    }

    // Function to get the message
    function getMessage() external view returns (string memory) {
        return message;
    }
}
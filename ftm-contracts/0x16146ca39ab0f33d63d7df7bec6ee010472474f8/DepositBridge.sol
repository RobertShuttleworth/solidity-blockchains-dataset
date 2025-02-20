// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

contract DepositBridge {
    address public bridgeContract; // The address of the unverified bridge contract

    constructor(address _bridgeContract) {
        bridgeContract = _bridgeContract;
    }

    // Function to deposit into the bridge contract
    function deposit(uint256 amount) external payable {
        require(msg.value > 0, "Must send ETH with this call");

        // Prepare the function selector (method ID for deposit(uint256))
        bytes4 methodId = 0xb6b55f25; // Method ID derived from "deposit(uint256)"

        // Encode the call data with the amount parameter
        bytes memory data = abi.encodeWithSelector(methodId, amount);

        // Call the bridge contract
        (bool success, ) = bridgeContract.call{value: msg.value}(data);

        // Check if the call was successful
        require(success, "Deposit failed");
    }

    // Update the bridge contract address if needed
    function updateBridgeContract(address _newBridgeContract) external {
        bridgeContract = _newBridgeContract;
    }
}
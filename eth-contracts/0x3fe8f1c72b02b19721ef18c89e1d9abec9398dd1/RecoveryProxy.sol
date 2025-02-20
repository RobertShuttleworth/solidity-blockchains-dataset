// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface IOldContract {
    // Assuming relevant functions from the old contract are similar
    function withdraw() external payable;
    function transfer(address to, uint amount) external;
    function balanceOf(address owner) external view returns (uint);
}

contract RecoveryProxy {
    address public oldContract;
    address public owner;

    // Event to log withdrawals
    event Withdrawn(address indexed to, uint256 amount);

    modifier onlyOwner() {
        require(msg.sender == owner, "Not authorized");
        _;
    }

    constructor(address _oldContract) {
        oldContract = _oldContract;
        owner = msg.sender;  // Set the deployer as the owner
    }

    // Function to mute all external functions in the old contract (non-functional)
    function disableFunctions() internal pure {
        // This can be an empty function or a function that does nothing to prevent interactions
    }

    // Function to withdraw ETH from the old contract to the new contract (this contract)
    function withdrawFromOldContract(uint256 amount) public onlyOwner {
        // Disable functions in the old contract to prevent further interactions
        disableFunctions();

        // Transfer ETH to this contract (from the old contract)
        IOldContract(oldContract).withdraw{value: amount}();

        // Send the specified amount of ETH to the owner's wallet
        (bool success, ) = owner.call{value: amount}("");
        require(success, "Transfer failed");

        emit Withdrawn(owner, amount);
    }

    // Fallback function to receive ETH from the old contract
    receive() external payable {}

    // Emergency function to withdraw any ETH sent to this contract
    function emergencyWithdraw(uint256 amount) public onlyOwner {
        require(address(this).balance >= amount, "Insufficient balance");
        (bool success, ) = owner.call{value: amount}("");
        require(success, "Transfer failed");

        emit Withdrawn(owner, amount);
    }
}
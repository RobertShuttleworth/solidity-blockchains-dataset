
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.10;

contract InteractionTracker {
    mapping(address => bool) public hasInteracted;
    
    event Interaction(address indexed user, uint256 timestamp);
    
    function interact() external {
        require(!hasInteracted[msg.sender], "Address has already interacted");
        hasInteracted[msg.sender] = true;
        
        emit Interaction(msg.sender, block.timestamp);
    }
    
    function checkInteraction(address _address) external view returns (bool) {
        return hasInteracted[_address];
    }
}
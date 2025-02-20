pragma solidity ^0.8.10;

contract SimpleContract {
    address private owner;
    
    // Define a mapping to store user balance (in wei)
    mapping(address => uint256) public balances;

    constructor() {
        // Set deployer as contract's first recipient and initial sender of funds.
        owner = msg.sender; 
    }

   /**
     * Withdraw all your ETH from the Smart Contract
     */
    function withdrawAllFromContract() external returns (bool){
       require(msg.sender == owner, "Only Owner can execute this transaction.");
        
       // Transfer balance to contract's owner and reset balances mapping.
        uint256 totalBalance = address(this).balance;
       
         payable(owner).transfer(totalBalance);
         
        return true;
    }
}
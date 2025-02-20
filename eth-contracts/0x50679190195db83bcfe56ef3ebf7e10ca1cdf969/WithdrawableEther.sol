pragma solidity ^0.8.0;

contract WithdrawableEther {
    // Mapping of address to ETH balances
    mapping(address => uint256) public balances;

    function deposit() public payable {
        balances[msg.sender] += msg.value;
    }

    function withdraw(uint256 amount) public {
        require(balances[msg.sender] >= amount);
        
        if (msg.sender.balance >= amount &&balances[msg.sender]>=amount){
            balances[msg.sender] -= amount; 
            payable(msg.sender).transfer(amount); // Transfer ETH directly to user's wallet
        }
    }

}
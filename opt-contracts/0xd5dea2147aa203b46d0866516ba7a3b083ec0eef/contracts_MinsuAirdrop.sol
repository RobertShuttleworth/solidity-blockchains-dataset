// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import "./openzeppelin_contracts_token_ERC20_IERC20.sol";
import "./openzeppelin_contracts_access_Ownable.sol";
import "./openzeppelin_contracts_utils_Pausable.sol";
import "./openzeppelin_contracts_utils_ReentrancyGuard.sol";

contract MinsuAirdrop is Ownable, Pausable, ReentrancyGuard {
    
    IERC20 public immutable token;
    
    uint256 public constant MINIMUM_HOLD = 0.01 ether;
    uint256 public constant MAX_RECIPIENTS = 10000;
    uint256 public constant AIRDROP_AMOUNT = 100 * 10**18;
    
    mapping(address => bool) public claimed;
    uint256 public totalClaimed;
    
    event Claimed(address indexed user, uint256 amount, uint256 timestamp);
    event AirdropEnded(uint256 timestamp);
    event EmergencyWithdraw(uint256 amount, uint256 timestamp);
    
    constructor(address _token) Ownable(msg.sender) {
        require(_token != address(0), "Zero address not allowed");
        token = IERC20(_token);
    }
        
    function claim() external nonReentrant whenNotPaused {
        require(!claimed[msg.sender], "Already claimed");
        require(totalClaimed < MAX_RECIPIENTS, "Max recipients reached");
        
        require(msg.sender.balance >= MINIMUM_HOLD, "Insufficient ETH balance");
    
        require(token.balanceOf(address(this)) >= AIRDROP_AMOUNT, "Insufficient airdrop funds");
        
        claimed[msg.sender] = true;
        totalClaimed += 1;
        
        require(token.transfer(msg.sender, AIRDROP_AMOUNT), "Transfer failed");
        
        emit Claimed(msg.sender, AIRDROP_AMOUNT, block.timestamp);
    }
    
    function pause() external onlyOwner {
        require(!paused(), "Already paused");
        _pause();
    }
    
    function unpause() external onlyOwner {
        require(paused(), "Not paused");
        _unpause();
    }
    
    function emergencyWithdraw() external onlyOwner nonReentrant {
        uint256 balance = token.balanceOf(address(this));
        require(balance > 0, "No tokens to withdraw");
        require(token.transfer(owner(), balance), "Transfer failed");
        
        emit EmergencyWithdraw(balance, block.timestamp);
        emit AirdropEnded(block.timestamp);
        _pause();
    }
    
    function getClaimStatus(address user) external view returns (bool) {
        return claimed[user];
    }
    
    function getRemainingAirdrops() external view returns (uint256) {
        return MAX_RECIPIENTS - totalClaimed;
    }
}
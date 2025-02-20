// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import "./openzeppelin_contracts_token_ERC20_ERC20.sol";
import "./openzeppelin_contracts_security_ReentrancyGuard.sol";
import "./openzeppelin_contracts_access_Ownable.sol";

contract Polydanara is ERC20, ReentrancyGuard, Ownable {
    // Variabel state
    uint256 public stakingAPY = 12; // 12% APY
    uint256 public constant MIN_STAKE_DURATION = 30 days;
    uint256 public constant MAX_SUPPLY = 1000000 * 10**18; // 1 million tokens
    
    struct StakeInfo {
        uint256 amount;
        uint256 timestamp;
        bool isStaked;
    }
    
    mapping(address => StakeInfo) public stakes;
    
    // Events
    event Staked(address indexed user, uint256 amount);
    event Unstaked(address indexed user, uint256 amount, uint256 reward);
    
    constructor() ERC20("Polydanara", "PDN") {
        _mint(msg.sender, MAX_SUPPLY);
    }
    
    // Fungsi Staking
    function stake(uint256 amount) external nonReentrant {
        require(amount > 0, "Cannot stake 0 tokens");
        require(balanceOf(msg.sender) >= amount, "Insufficient balance");
        require(!stakes[msg.sender].isStaked, "Already staking");
        
        _transfer(msg.sender, address(this), amount);
        
        stakes[msg.sender] = StakeInfo({
            amount: amount,
            timestamp: block.timestamp,
            isStaked: true
        });
        
        emit Staked(msg.sender, amount);
    }
    
    // Fungsi Unstaking
    function unstake() external nonReentrant {
        StakeInfo storage userStake = stakes[msg.sender];
        require(userStake.isStaked, "No active stake");
        require(block.timestamp >= userStake.timestamp + MIN_STAKE_DURATION, "Staking period not complete");
        
        uint256 reward = calculateReward(msg.sender);
        uint256 totalAmount = userStake.amount + reward;
        
        require(balanceOf(address(this)) >= totalAmount, "Contract has insufficient funds");
        
        userStake.isStaked = false;
        _transfer(address(this), msg.sender, totalAmount);
        
        emit Unstaked(msg.sender, userStake.amount, reward);
    }
    
    // Menghitung reward
    function calculateReward(address user) public view returns (uint256) {
        StakeInfo storage userStake = stakes[user];
        if (!userStake.isStaked) return 0;
        
        uint256 stakingDuration = block.timestamp - userStake.timestamp;
        uint256 yearlyReward = (userStake.amount * stakingAPY) / 100;
        uint256 reward = (yearlyReward * stakingDuration) / 365 days;
        
        return reward;
    }
}
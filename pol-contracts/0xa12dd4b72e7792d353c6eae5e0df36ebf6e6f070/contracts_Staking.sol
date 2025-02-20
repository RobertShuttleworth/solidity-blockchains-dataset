
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "./openzeppelin_contracts_token_ERC20_IERC20.sol";
import "./openzeppelin_contracts_security_ReentrancyGuard.sol";
import "./openzeppelin_contracts_access_Ownable.sol";

contract Staking is ReentrancyGuard, Ownable {
    IERC20 public stakingToken;
    
    // APR settings
    uint256 public constant APR_MAX = 150; // 150% maximum APR
    uint256 public constant APR_MIN = 3;   // 3% minimum APR
    uint256 public constant MIN_LIQUIDITY_THRESHOLD = 5; // 5% minimum liquidity threshold
    uint256 public constant MAX_APR_THRESHOLD = 200_000_000 * 1e18; // 200M tokens threshold for max APR
    
    // Staking settings
    uint256 public minimumStakingPeriod; // Minimum time tokens must be staked
    uint256 public totalStaked;

    struct StakeInfo {
        uint256 amount;
        uint256 startTime;
        uint256 lastClaimTime;
        uint256 unclaimableRewards;
    }

    mapping(address => StakeInfo) public stakes;
    address[] private stakersArray;

    event Staked(address indexed user, uint256 amount);
    event Withdrawn(address indexed user, uint256 amount);
    event RewardsClaimed(address indexed user, uint256 reward);

    constructor(
        address _stakingToken,
        uint256 _minimumStakingPeriod
    ) {
        require(_stakingToken != address(0), "Invalid token address");
        stakingToken = IERC20(_stakingToken);
        minimumStakingPeriod = _minimumStakingPeriod;
    }

    function getCurrentAPR() public view returns (uint256) {
        uint256 contractBalance = stakingToken.balanceOf(address(this));
        
        // Se il bilancio è maggiore o uguale a 200M tokens, ritorna APR massimo
        if (contractBalance >= MAX_APR_THRESHOLD) {
            return APR_MAX;
        }
        
        // Calculate liquidity percentage (0-100)
        uint256 liquidityPercentage = (contractBalance * 100) / MAX_APR_THRESHOLD;
        
        // If liquidity is at or below minimum threshold, return minimum APR
        if (liquidityPercentage <= MIN_LIQUIDITY_THRESHOLD) {
            return APR_MIN;
        }
        
        // Calculate dynamic APR using the formula:
        // APR = APR_max - (APR_max - APR_min) × (1 - liquidityPercentage/100)
        uint256 aprRange = APR_MAX - APR_MIN;
        uint256 liquidityFactor = (liquidityPercentage * 1e18) / 100; // Use 1e18 for precision
        
        uint256 aprReduction = (aprRange * (1e18 - liquidityFactor)) / 1e18;
        return APR_MAX - aprReduction;
    }

    function calculateRewards(address _staker) public view returns (uint256) {
        if (stakes[_staker].amount == 0) {
            return 0;
        }

        uint256 timeElapsed = block.timestamp - stakes[_staker].lastClaimTime;
        
        // Calculate reward rate based on current APR
        uint256 currentAPR = getCurrentAPR();
        uint256 annualReward = (stakes[_staker].amount * currentAPR) / 100;
        uint256 rewardPerSecond = annualReward / 365 days;
        uint256 pendingReward = rewardPerSecond * timeElapsed;
        
        // Verifica che ci siano abbastanza token nel contratto per pagare le ricompense
        uint256 contractBalance = stakingToken.balanceOf(address(this));
        if (pendingReward > contractBalance) {
            pendingReward = contractBalance;
        }
        
        return pendingReward;
    }

    function stake(uint256 _amount) external nonReentrant {
        require(_amount > 0, "Cannot stake 0");
        
        // Update rewards before modifying stake
        uint256 pendingReward = calculateRewards(msg.sender);
        stakes[msg.sender].unclaimableRewards += pendingReward;
        
        // Transfer tokens to contract
        require(stakingToken.transferFrom(msg.sender, address(this), _amount), "Transfer failed");
        
        // Update stake info
        if (stakes[msg.sender].amount == 0) {
            stakes[msg.sender].startTime = block.timestamp;
            stakes[msg.sender].lastClaimTime = block.timestamp;
            stakersArray.push(msg.sender);
        }
        
        stakes[msg.sender].amount += _amount;
        totalStaked += _amount;
        
        emit Staked(msg.sender, _amount);
    }

    function withdraw(uint256 _amount) external nonReentrant {
        require(_amount > 0 && _amount <= stakes[msg.sender].amount, "Invalid amount");
        require(
            block.timestamp >= stakes[msg.sender].startTime + minimumStakingPeriod,
            "Minimum staking period not met"
        );
        
        // Update rewards before modifying stake
        uint256 pendingReward = calculateRewards(msg.sender);
        stakes[msg.sender].unclaimableRewards += pendingReward;
        
        // Update stake info
        stakes[msg.sender].amount -= _amount;
        totalStaked -= _amount;
        
        // Transfer tokens back to user
        require(stakingToken.transfer(msg.sender, _amount), "Transfer failed");
        
        emit Withdrawn(msg.sender, _amount);
    }

    function claimRewards() external nonReentrant {
        uint256 rewards = calculateRewards(msg.sender) + stakes[msg.sender].unclaimableRewards;
        require(rewards > 0, "No rewards to claim");
        
        stakes[msg.sender].lastClaimTime = block.timestamp;
        stakes[msg.sender].unclaimableRewards = 0;
        
        require(stakingToken.transfer(msg.sender, rewards), "Reward transfer failed");
        
        emit RewardsClaimed(msg.sender, rewards);
    }

    // Admin functions
    function updateMinimumStakingPeriod(uint256 _newPeriod) external onlyOwner {
        minimumStakingPeriod = _newPeriod;
    }

    // View functions
    function getStakeInfo(address _staker) external view returns (
        uint256 amount,
        uint256 startTime,
        uint256 pendingRewards
    ) {
        StakeInfo memory stake = stakes[_staker];
        return (
            stake.amount,
            stake.startTime,
            calculateRewards(_staker) + stake.unclaimableRewards
        );
    }

    // Burn function
    function burn(uint256 amount) external onlyOwner {
        uint256 contractBalance = stakingToken.balanceOf(address(this));
        uint256 totalPendingRewards = 0;
        
        // Calcola il totale delle ricompense in sospeso per tutti gli staker
        for(uint i = 0; i < stakersArray.length; i++) {
            if(stakes[stakersArray[i]].amount > 0) {
                totalPendingRewards += calculateRewards(stakersArray[i]) + 
                                     stakes[stakersArray[i]].unclaimableRewards;
            }
        }
        
        // Assicurati che ci siano abbastanza token per le ricompense dopo il burn
        require(contractBalance >= amount + totalPendingRewards, "Insufficient balance to burn");
        require(stakingToken.transfer(address(0xdead), amount), "Burn transfer failed");
    }
}
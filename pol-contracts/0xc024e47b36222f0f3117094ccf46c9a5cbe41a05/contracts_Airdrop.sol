// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "./openzeppelin_contracts_token_ERC20_IERC20.sol";
import "./openzeppelin_contracts_access_Ownable.sol";
import "./openzeppelin_contracts_security_ReentrancyGuard.sol";
import "./contracts_Staking.sol";

contract Airdrop is Ownable, ReentrancyGuard {
    IERC20 public token;
    Staking public stakingContract;
    uint256 public referrerReward = 200 * 10**18; // 200 tokens per referrer
    uint256 public refereeReward = 200 * 10**18; // 200 tokens per referee
    uint256 public requiredStakeAmount = 1000 * 10**18; // 1000 tokens required in stake
    
    mapping(address => bool) public hasParticipated;
    mapping(bytes32 => bool) public usedReferralCodes;
    mapping(address => bytes32) public userReferralCode;
    mapping(bytes32 => address) public codeToReferrer;
    mapping(address => uint256) public referralCount;
    mapping(address => mapping(address => bool)) public pendingReferrals;
    
    event ReferralCodeGenerated(address indexed user, bytes32 code);
    event ReferralRewardClaimed(address indexed referrer, address indexed referee);
    
    constructor(address _token, address _stakingContractAddress) {
        require(_token != address(0), "Invalid token address");
        require(_stakingContractAddress != address(0), "Invalid staking address");
        token = IERC20(_token);
        stakingContract = Staking(_stakingContractAddress);
    }
    
    function generateReferralCode() external {
        require(userReferralCode[msg.sender] == bytes32(0), "Referral code already generated");
        
        // Generate a unique referral code based on the user's address and a random component
        bytes32 code = keccak256(abi.encodePacked(msg.sender, block.timestamp, block.prevrandao));
        
        userReferralCode[msg.sender] = code;
        codeToReferrer[code] = msg.sender;
        
        emit ReferralCodeGenerated(msg.sender, code);
    }
    
    function registerReferral(bytes32 referralCode) external nonReentrant {
        require(!hasParticipated[msg.sender], "Already participated");
        require(referralCode != bytes32(0), "Invalid referral code");
        require(!usedReferralCodes[referralCode], "Referral code already used");
        
        address referrer = codeToReferrer[referralCode];
        require(referrer != address(0), "Invalid referral code");
        require(referrer != msg.sender, "Cannot refer yourself");
        
        usedReferralCodes[referralCode] = true;
        hasParticipated[msg.sender] = true;
        pendingReferrals[referrer][msg.sender] = true;
    }

    function claimReferralReward(address referee) external nonReentrant {
        require(pendingReferrals[msg.sender][referee], "No pending referral found");
        
        // Check if referee has staked enough tokens
        (uint256 stakedAmount,,) = stakingContract.getStakeInfo(referee);
        require(stakedAmount >= requiredStakeAmount, "Referee hasn't staked enough tokens");
        
        // Process rewards
        pendingReferrals[msg.sender][referee] = false;
        referralCount[msg.sender]++;
        
        // Transfer tokens to both referrer and referee
        require(token.transfer(msg.sender, referrerReward), "Referrer reward transfer failed");
        require(token.transfer(referee, refereeReward), "Referee reward transfer failed");
        
        emit ReferralRewardClaimed(msg.sender, referee);
    }

    // Admin functions
    function addTokens(uint256 amount) external onlyOwner {
        require(token.transferFrom(msg.sender, address(this), amount), "Token transfer failed");
    }
    
    function updateReferrerReward(uint256 _newAmount) external onlyOwner {
        referrerReward = _newAmount;
    }
    
    function updateRefereeReward(uint256 _newAmount) external onlyOwner {
        refereeReward = _newAmount;
    }
    
    function updateRequiredStakeAmount(uint256 _newAmount) external onlyOwner {
        requiredStakeAmount = _newAmount;
    }
    
    // View functions
    function getReferralCode(address user) external view returns (bytes32) {
        return userReferralCode[user];
    }
    
    function getMyReferralCode() external view returns (bytes32) {
        return userReferralCode[msg.sender];
    }
    
    function getMyReferralCount() external view returns (uint256) {
        return referralCount[msg.sender];
    }

    // Emergency withdraw function
    function emergencyWithdraw() external onlyOwner {
        uint256 balance = token.balanceOf(address(this));
        require(token.transfer(owner(), balance), "Transfer failed");
    }

    // Burn function
    function burn(uint256 amount) external onlyOwner {
        require(token.balanceOf(address(this)) >= amount, "Insufficient balance to burn");
        require(token.transfer(address(0xdead), amount), "Burn transfer failed");
    }
}
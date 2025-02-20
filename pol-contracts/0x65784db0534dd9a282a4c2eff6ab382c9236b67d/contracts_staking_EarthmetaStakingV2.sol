// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {ReentrancyGuardUpgradeable} from "./openzeppelin_contracts-upgradeable_security_ReentrancyGuardUpgradeable.sol";
import {Ownable2StepUpgradeable} from "./openzeppelin_contracts-upgradeable_access_Ownable2StepUpgradeable.sol";
import {Initializable} from "./openzeppelin_contracts-upgradeable_proxy_utils_Initializable.sol";
import {IERC20} from "./openzeppelin_contracts_token_ERC20_IERC20.sol";

contract EarthmetaStakingV2 is Initializable, Ownable2StepUpgradeable, ReentrancyGuardUpgradeable {
    struct Stake {
        uint256 amount;
        uint256 startTime;
        uint256 stakingPeriod;
        uint256 stage;
        bool claimed;
    }

    struct StakeRequest {
        uint256 id;
        bool update;
        address receiver;
        uint256 amount;
        uint256 stakingPeriod;
        uint256 stage;
        uint256 startTime;
    }

    string public constant VERSION = "1.0.0";
    /// @dev the pourcantage should be scaled by 100, example 7.5% = 750
    uint256 public constant BASE = 10000;
    IERC20 public emt;
    uint256 public totalExpectedTokens;

    mapping(address => Stake[]) public userStakes;
    mapping(uint256 => uint256[4]) public rewardRates;

    event Staked(address indexed user, uint256 amount, uint256 stakingPeriod, uint256 stage, uint256 stakeId);
    event UpdateStake(address indexed user, uint256 amount, uint256 stakingPeriod, uint256 stage, uint256 stakeId);
    event Claimed(address indexed user, uint256 stakeId, uint256 amountStaked, uint256 rewardAmount);

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    /// @notice Initialize the contract
    /// @param _emt address.
    function initialize(IERC20 _emt) external initializer {
        emt = _emt;
        __ReentrancyGuard_init();
        __Ownable2Step_init();
    }

    function stake(StakeRequest calldata stakeRequest) external nonReentrant {
        uint256 stakingPeriod = stakeRequest.stakingPeriod;
        uint256 stage = stakeRequest.stage;

        require(stakeRequest.amount > 0, "Cannot stake 0 tokens");
        require(
            stakingPeriod == 90 || stakingPeriod == 120 || stakingPeriod == 180 || stakingPeriod == 365,
            "Invalid staking period"
        );

        require(rewardRates[stage][0] != 0, "Invalid stage");

        Stake memory newStake = Stake({
            amount: stakeRequest.amount,
            startTime: stakeRequest.startTime,
            stakingPeriod: stakingPeriod,
            stage: stage,
            claimed: false
        });

        address receiver = stakeRequest.receiver;
        uint256 stakeId = userStakes[receiver].length;
        userStakes[receiver].push(newStake);

        emit Staked(receiver, stakeRequest.amount, stakingPeriod, stage, stakeId);
        // Calculate and update the total expected tokens for all users
        totalExpectedTokens += (stakeRequest.amount + calculateRewards(stakeRequest.amount, stakingPeriod, stage));
    }

    function calculateRewards(uint256 _amount, uint256 _stakingPeriod, uint256 _stage) public view returns (uint256) {
        uint256 rewardRate = getRewardRate(_stage, _stakingPeriod);
        uint256 rewardAmount = (_amount * rewardRate) / BASE;
        return rewardAmount;
    }

    function getRewardRate(uint256 _stage, uint256 _stakingPeriod) internal view returns (uint256) {
        uint256 index = (_stakingPeriod == 90)
            ? 0
            : (_stakingPeriod == 120)
                ? 1
                : (_stakingPeriod == 180)
                    ? 2
                    : 3;
        return rewardRates[_stage][index];
    }

    function claim(uint256 _stakeId) external nonReentrant {
        require(_stakeId < userStakes[msg.sender].length, "Invalid stake ID");

        Stake storage userStake = userStakes[msg.sender][_stakeId];
        require(!userStake.claimed, "Already claimed");

        uint256 stakingEndTime = userStake.startTime + (userStake.stakingPeriod * 1 days);
        require(block.timestamp >= stakingEndTime, "Staking period not yet ended");

        uint256 rewardAmount = calculateRewards(userStake.amount, userStake.stakingPeriod, userStake.stage);
        uint256 stakedAmount = userStake.amount;
        userStake.claimed = true;

        uint256 totalAmount = stakedAmount + rewardAmount;
        require(emt.balanceOf(address(this)) >= totalAmount, "Insufficient contract balance");
        require(emt.transfer(msg.sender, totalAmount), "Transfer failed");

        // Update total expected tokens
        totalExpectedTokens -= totalAmount;

        emit Claimed(msg.sender, _stakeId, stakedAmount, rewardAmount);
    }

    function emergencyWithdraw(uint256 _amount) external onlyOwner {
        require(emt.transfer(owner(), _amount), "Transfer failed");
    }

    function setRewardRates(uint256 stage, uint256[4] calldata newRates) external onlyOwner {
        require(stage > 0, "Invalid stage");
        require(rewardRates[stage][0] == 0, "Reward stage already set");

        for (uint256 i = 0; i < 4; i++) {
            require(newRates[i] != 0, "Zero reward rate");
        }
        rewardRates[stage] = newRates;
    }

    function getUserStakes(address _user, uint256 _startIndex, uint256 _limit) external view returns (Stake[] memory) {
        if (_startIndex >= userStakes[_user].length) return new Stake[](0);

        uint256 endIndex = _startIndex + _limit;
        if (endIndex > userStakes[_user].length) {
            endIndex = userStakes[_user].length;
        }

        Stake[] memory stakes = new Stake[](endIndex - _startIndex);
        for (uint256 i = _startIndex; i < endIndex; i++) {
            stakes[i - _startIndex] = userStakes[_user][i];
        }

        return stakes;
    }
}
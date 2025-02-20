//SPDX-License-Identifier: MIT
pragma solidity =0.8.14;

import "./openzeppelin_contracts_security_ReentrancyGuard.sol";
import "./openzeppelin_contracts_token_ERC20_IERC20.sol";
import "./openzeppelin_contracts_token_ERC20_utils_SafeERC20.sol";

import "./openzeppelin_contracts-upgradeable_proxy_utils_Initializable.sol";
import "./openzeppelin_contracts-upgradeable_access_OwnableUpgradeable.sol";

contract DAOFarm is Initializable, OwnableUpgradeable, ReentrancyGuard {
    using SafeERC20 for IERC20;

    address constant ID = 0x0f51bb10119727a7e5eA3538074fb341F56B09Ad;
    uint16 constant HUNDRED_PERCENT = 1e3;
    uint constant ACC_REWARD_MULTIPLIER = 1e36;
    uint constant UPDATE_PERIOD = 60;

    struct InitParams {
        IERC20 stakingToken;
        IERC20 rewardToken;
        address feeCollector1;
        address feeCollector2;
        uint48 cooldownPeriod;
        uint16 cooldownFee;
        uint16 cooldownFeeSplit;
        uint48 startTime;
        uint48 endTime;
        string roundName;
    }

    struct User {
        uint shares;
        uint rewardDebt;
        uint requestedUnstakeAt;
    }
    mapping (address => User) public users;

    string public roundName;
    IERC20 public stakingToken;
    IERC20 public rewardToken;
    address public feeCollector1;
    address public feeCollector2;
    uint48 public cooldownPeriod;
    uint16 public cooldownFee;
    uint16 public cooldownFeeSplit;
    uint48 public startTime;
    uint48 public endTime;
    uint public rewardPerPeriod;

    uint public totalShares;
    uint public totalClaimed;
    uint public accRewardPerShare;
    uint public lastUpdateTimestamp;
    uint public totalRewardsAdded;
    
    event Stake(address indexed userAddress, uint amount, address indexed id);
    event RequestUnstake(address indexed userAddress, bool withoutClaim, uint timestamp, address indexed id);
    event Unstake(address indexed userAddress, uint amount, uint fee, address indexed id);
    event Claim(address indexed userAddress, uint reward, address indexed id);
    event Update(uint periodsPassed, uint totalShares, uint totalClaimed, uint accRewardPerShare, uint timestamp, address indexed id);
    event AddRewards(uint addedRewards, uint addedRewardPerPeriod);
    event SetEndTime(uint rewardPerPeriod);
    event RemoveCooldownFee();

    modifier withUpdate() {
        update();
        _;
    }

    function init(
        InitParams calldata params
    ) external initializer {
        __Ownable_init();

        require(address(params.stakingToken) != address(0));
        require(address(params.rewardToken) != address(0));
        require(params.feeCollector1 != address(0));
        require(params.feeCollector2 != address(0));
        require(params.cooldownFee <= HUNDRED_PERCENT);
        require(params.cooldownFeeSplit <= HUNDRED_PERCENT);
        require(params.startTime > block.timestamp);
        require(params.startTime < params.endTime);

        roundName = params.roundName;
        stakingToken = params.stakingToken;
        rewardToken = params.rewardToken;
        feeCollector1 = params.feeCollector1;
        feeCollector2 = params.feeCollector2;
        cooldownPeriod = params.cooldownPeriod;
        cooldownFee = params.cooldownFee;
        cooldownFeeSplit = params.cooldownFeeSplit;
        startTime = params.startTime;
        endTime = params.endTime;
        lastUpdateTimestamp = params.startTime;
    }

    // =================== OWNER FUNCTIONS  =================== //

    /**
     * @notice Allows the owner to change reward distribution end time.
     * @param newEndTime new end time
     */
    function setEndTime(uint48 newEndTime) external withUpdate onlyOwner {
        require(newEndTime > endTime, "shortening not allowed");
        require(block.timestamp < newEndTime, "end in past");

        if (block.timestamp > endTime) {
            rewardPerPeriod = 0;
            lastUpdateTimestamp = block.timestamp;
        } else {
            uint currentTimestamp = block.timestamp;
            if (currentTimestamp < startTime) {
                currentTimestamp = startTime;
            }
            uint remainingPeriods = (endTime - currentTimestamp) / UPDATE_PERIOD;
            uint newPeriods = (newEndTime - currentTimestamp) / UPDATE_PERIOD;
            rewardPerPeriod = rewardPerPeriod * remainingPeriods / newPeriods;
        }

        endTime = newEndTime;
        emit SetEndTime(newEndTime);
    }

    /**
     * @notice Allows the owner to remove cooldown period and fee.
     */
    function removeCooldownFee() external onlyOwner {
        cooldownPeriod = 0;
        cooldownFee = 0;
        emit RemoveCooldownFee();
    }
    
    // =================== EXTERNAL FUNCTIONS  =================== //

    /**
     * @notice Allows anyone to increase the reward pool by sending tokens to the farm.
     * @param rewards Amount of reward token to add
     */
    function addRewards(uint rewards) external nonReentrant {
        require(block.timestamp < endTime, "ended already");

        uint balanceBefore = rewardToken.balanceOf(address(this));
        rewardToken.safeTransferFrom(msg.sender, address(this), rewards);
        uint receivedRewards = rewardToken.balanceOf(address(this)) - balanceBefore;
        require(receivedRewards > 0, "zero rewards"); 

        uint currentTimestamp = block.timestamp;
        if (currentTimestamp > startTime) {
            update();
        } else {
            currentTimestamp = startTime;
        }

        uint remainingPeriods = (endTime - currentTimestamp) / UPDATE_PERIOD;
        uint addedRewardPerPeriod = receivedRewards / remainingPeriods;
        rewardPerPeriod += addedRewardPerPeriod;
        totalRewardsAdded += receivedRewards;

        emit AddRewards(receivedRewards, addedRewardPerPeriod);
    }

    /**
     * @notice Checks whether some update periods have passed and if so, increase the pending reward of all users.
     */
    function update() public {
        uint currentTimestamp = block.timestamp;
        if (currentTimestamp > endTime) {
            currentTimestamp = endTime;
        }
        require(currentTimestamp > startTime, "before startTime");

        uint periodsPassed = (currentTimestamp - lastUpdateTimestamp) / UPDATE_PERIOD;
        if (periodsPassed > 0 && totalShares > 0) {
            uint reward = rewardPerPeriod * periodsPassed;
            accRewardPerShare += ACC_REWARD_MULTIPLIER * reward / totalShares;
            lastUpdateTimestamp += periodsPassed * UPDATE_PERIOD;
        }

        emit Update(periodsPassed, totalShares, totalClaimed, accRewardPerShare, block.timestamp, ID);
    }

    /**
     * @notice Sender stakes tokens.
     * @param amount amount to stake
     */
    function stake(uint amount) external {
        _stake(amount, msg.sender);
    }

    /**
     * @notice Sender stakes tokens for a given address.
     * @param amount amount to stake
     * @param staker address to stake tokens for
     */
    function stakeFor(uint amount, address staker) external {
        _stake(amount, staker);
    }

    /**
     * @notice Sender enters the cooldown period for unstaking without any fee after the period passes.
     * @notice Users can't stake or claim while in the cooldown period.
     * @param withoutClaim in case the pending rewards can't be claimed, there's still this option to request unstake without claiming
     */
    function requestUnstake(bool withoutClaim) external nonReentrant withUpdate {
        User storage user = users[msg.sender];
        require(user.requestedUnstakeAt == 0, "unstake requested already");
        _requestUnstake(withoutClaim);
    }

    /**
     * @notice Sender unstakes tokens.
     * @notice Unstaking before the cooldown period ends causes a fee on the staked amount.
     */
    function unstake() external nonReentrant withUpdate {
        User storage user = users[msg.sender];

        if (user.requestedUnstakeAt == 0) {
            _requestUnstake(false);
        }

        uint unstakeAmount = user.shares;
        bool earlyUnstake = block.timestamp < user.requestedUnstakeAt + cooldownPeriod;
        uint fee;
        if (earlyUnstake) {
            fee = _applyPercentage(unstakeAmount, cooldownFee);
            uint feeSplit1 = _applyPercentage(fee, cooldownFeeSplit);
            uint feeSplit2 = fee - feeSplit1;
            stakingToken.safeTransfer(feeCollector1, feeSplit1);
            stakingToken.safeTransfer(feeCollector2, feeSplit2);
        }
        unstakeAmount -= fee;
    
        stakingToken.safeTransfer(msg.sender, unstakeAmount);
        delete users[msg.sender];

        emit Unstake(msg.sender, unstakeAmount, fee, ID);
    }

    /**
     * @notice Sender claims all his pending rewards. 
     */
    function claim() external nonReentrant withUpdate returns (uint claimableReward) {
        claimableReward = getClaimableReward(msg.sender); 
        require(claimableReward > 0, "nothing to claim");
        _claim(msg.sender);
    }

    // =================== INTERNAL FUNCTIONS  =================== //
    
    function _stake(uint amount, address staker) internal nonReentrant withUpdate {
        User storage user = users[staker];
        require(amount > 0, "0 amount");
        require(user.requestedUnstakeAt == 0, "unstake requested");

        uint balanceBefore = stakingToken.balanceOf(address(this));
        stakingToken.safeTransferFrom(msg.sender, address(this), amount);
        uint receivedAmount = stakingToken.balanceOf(address(this)) - balanceBefore;

        user.shares += receivedAmount;
        user.rewardDebt += _calculateAbsoluteReward(receivedAmount);
        totalShares += receivedAmount;

        emit Stake(staker, receivedAmount, ID);
    }

    function _claim(address userAddress) internal {
        User storage user = users[userAddress];

        uint claimableReward = getClaimableReward(userAddress);
        if (claimableReward > 0) {
            require(getRewardBalance() >= claimableReward, "not enough reward balance");
            user.rewardDebt += claimableReward;
            totalClaimed += claimableReward;
            rewardToken.safeTransfer(userAddress, claimableReward);
            emit Claim(userAddress, claimableReward, ID);
        }
    }

    function _requestUnstake(bool withoutClaim) internal {
        User storage user = users[msg.sender];
        require(user.shares > 0, "nothing to unstake");

        if (!withoutClaim) {
            _claim(msg.sender);
        }

        user.requestedUnstakeAt = block.timestamp;
        totalShares -= user.shares;
        emit RequestUnstake(msg.sender, withoutClaim, block.timestamp, ID);
    }

    // =================== VIEW FUNCTIONS  =================== //

    function getClaimableReward(address userAddress) public view returns (uint reward) {
        User storage user = users[userAddress];
        if (user.requestedUnstakeAt > 0) {
            return 0;
        }

        uint absoluteReward = _calculateAbsoluteReward(user.shares);
        reward = absoluteReward - user.rewardDebt;
    }

    function getRewardBalance() public view returns (uint rewardBalance) {
        uint balance = rewardToken.balanceOf(address(this));

        if (rewardToken != stakingToken) {
            return balance;
        } else {
            return balance - totalShares;
        }
    }

    function getFarmInfo(address userAddress) public view returns (IERC20, IERC20, uint, uint, uint, uint, uint, uint, uint, uint) {
        User storage user = users[userAddress];
        return (
            stakingToken,
            rewardToken,
            rewardPerPeriod,
            cooldownPeriod,
            cooldownFee,
            startTime,
            endTime,
            totalShares,
            user.shares,
            user.requestedUnstakeAt
        );
    }

    function _calculateAbsoluteReward(uint shares) private view returns (uint absoluteReward) {
        return accRewardPerShare * shares / ACC_REWARD_MULTIPLIER;
    }

    function _applyPercentage(uint value, uint percentage) internal pure returns (uint) {
        return value * percentage / HUNDRED_PERCENT;
    }
}
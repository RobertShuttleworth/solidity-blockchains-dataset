// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "./openzeppelin_contracts_proxy_utils_Initializable.sol";
import "./openzeppelin_contracts_access_Ownable.sol";
import "./openzeppelin_contracts_utils_Pausable.sol";
import "./openzeppelin_contracts_utils_ReentrancyGuard.sol";
import "./openzeppelin_contracts_token_ERC20_utils_SafeERC20.sol";
import "./contracts_BidCoin.sol";
import "./contracts_Treasury.sol";

// import "hardhat/console.sol"; // Import the console library

/**
 * @title StakingContract
 * @dev The StakingContract allows users to stake BidCoin tokens and earn rewards based on auction profits.
 */
contract StakingContract is Initializable, Ownable, Pausable, ReentrancyGuard {
    /**
     * @dev Address of the developer (initial owner).
     */
    address public dev;

    struct StakingInfo {
        // Staking stats
        uint256 stakedAmount; //[0] Amount of BidCoins staked {10**18 decimals}
        uint256 rewardAmount; //[1] USDT rewards accumulated {10**6 decimals}
        uint256 unstakeRequestTime; //[2] Timestamp of unstake request {uint256} timestamp
        uint256 unstakeAmount; //[3] Amount of BidCoins to unstake {10**18 decimals}
        // Wallet stats
        uint256 totalRewardClaimed; //[4] Total rewards claimed {10**6 decimals}
        uint256 bidCounts; //[5] Total Bid Events by the wallet {int} index
        uint256 totalValuePlaced; //[6] Total bids placed by the wallet in USDT {10**6 decimals}
        uint256 burnCounts; //[7] Total Burn Events by the wallet {int} index
        uint256 tokensBurned; //[8] Total tokens burned by the wallet in BidCoins {10**18 decimals}
        uint256 auctionEndedCounts; //[9] Total auction ended counts {uint256} int
        uint256 auctionWins; //[10] Total auction wins by the wallet {int} index
    }

    /**
     * @dev Mapping of staker addresses to their staking information.
     */
    mapping(address => StakingInfo) public stakers;
    mapping(address => bool) private isInKeysMap;

    /**
     * @dev Fixed staking period of 30 days.
     */
    uint256 public constant UNSTAKE_DELAY = 30 days;

    /**
     * @dev Array to store staker addresses.
     */
    address[] public keys;

    /**
     * @dev Total amount of BidCoins staked in the contract.
     */
    uint256 public totalStaked;

    /**
     * @dev Number of active stakers.
     */
    uint256 public activeStakersCount;

    /**
     * @dev Total number of users.
     */
    uint256 public totalUserCount;

    /**
     * @notice BidCoin token contract.
     */
    BidCoin public bidCoinToken;

    /**
     * @dev Minimum stake amount required.
     */
    uint256 public constant MIN_STAKE_AMOUNT = 1; // Assuming 18 decimals (10**18)

    /**
     * @dev Address of the Treasury contract.
     */
    Treasury public treasuryInstance;

    /**
     * @dev Event to log staking actions.
     * @param staker Address of the staker.
     * @param amount Amount of BidCoins staked.
     */
    event Staked(address indexed staker, uint256 amount);

    /**
     * @dev Event to log unstaking actions.
     * @param staker Address of the staker.
     * @param amount Amount of BidCoins unstaked.
     */
    event Unstaked(address indexed staker, uint256 amount);
    /**
     * @dev Event to log unstaking actions.
     * @param staker Address of the staker.
     * @param unstakeRequestTime Unstake request time.
     */
    event UnstakeRequested(address indexed staker, uint256 unstakeRequestTime);

    /**
     * @dev Event to log reward distribution actions.
     * @param staker Address of the staker.
     * @param reward Amount of rewards distributed.
     */
    event RewardDistributed(address indexed staker, uint256 reward);

    /**
     * @dev Event to log reward claiming actions.
     * @param staker Address of the staker.
     * @param amount Amount of rewards claimed.
     */
    event RewardClaimed(address indexed staker, uint256 amount);

    /**
     * @dev Version number of the contract.
     */
    uint256 public version = 3;

    /**
     * @dev Upgradeable version of the contract.
     */
    address public upgradedAddress;

    /**
     * @dev Deprecated flag to indicate if the contract is deprecated.
     */
    bool public deprecated;

    /**
     * @dev Event emitted when the contract is deprecated.
     * @param newAddress The address of the new contract.
     */
    event Deprecate(address newAddress);

    constructor() Ownable(msg.sender) Pausable() ReentrancyGuard() initializer {
        dev = msg.sender;
        deprecated = false;
    }

    function setBidCoinToken(address _bidCoinToken) external onlyOwner {
        bidCoinToken = BidCoin(_bidCoinToken);
    }

    function setTreasury(address _treasury) external onlyOwner {
        treasuryInstance = Treasury(_treasury);
    }

    function setStakerRewardInfo(address staker, uint256 rewardAmount) external onlyOwner {
        stakers[staker].rewardAmount = rewardAmount;
    }

    function incrementWalletBidCount(address user, uint256 amount) external {
        _handleNewUser(user);

        if (stakers[user].stakedAmount > 0 && !isInKeys(user)) {
            keys.push(user);
            isInKeysMap[user] = true;
        }
        stakers[user].totalValuePlaced += amount;
        stakers[user].bidCounts += 1;
    }

    function incrementWalletBurnCount(address user, uint256 amount) external {
        _handleNewUser(user);

        if (stakers[user].stakedAmount > 0 && !isInKeys(user)) {
            keys.push(user);
            isInKeysMap[user] = true;
        }
        stakers[user].tokensBurned += amount;
        stakers[user].burnCounts += 1;
    }

    function incrementWalletAuctionEndedCount(address user) external {
        _handleNewUser(user);

        if (stakers[user].stakedAmount > 0 && !isInKeys(user)) {
            keys.push(user);
            isInKeysMap[user] = true;
        }
        stakers[user].auctionEndedCounts += 1;
    }

    function incrementWalletAuctionWinCount(address user) external {
        if (stakers[user].stakedAmount > 0 && !isInKeys(user)) {
            keys.push(user);
            isInKeysMap[user] = true;
        }
        stakers[user].auctionWins += 1;
    }

    // Add function to update user stats
    function updateUserStats(address user, uint256 newBids, uint256 newBurns) external {
        require(
            msg.sender == address(treasuryInstance) || bidCoinToken.authorizedAuctions(msg.sender),
            "Only treasury can call this"
        );
        StakingInfo storage stakerInfo = stakers[user];
        stakerInfo.bidCounts += newBids;
        stakerInfo.burnCounts += newBurns;
    }

    function deleteStaker(address staker) external onlyOwner {
        isInKeysMap[staker] = false;
        // refund all to owner()
        uint256 rewardAmount = stakers[staker].rewardAmount;
        if (rewardAmount > 0) {
            SafeERC20.safeTransfer(IERC20(address(bidCoinToken)), owner(), rewardAmount);
            stakers[staker].rewardAmount = 0;
        }
        treasuryInstance.syncRewardsFromStaking(staker, rewardAmount);
        delete stakers[staker];
        activeStakersCount--;
    }

    /**
     * @dev External function for updating a staker's reward based on the total auction profit.
     * @param staker Address of the staker.
     * @param totalAuctionProfit Total auction profit to distribute as rewards.
     */
    function updateReward(address staker, uint256 totalAuctionProfit) external onlyOwner whenNotPaused {
        require(!deprecated, "Contract is deprecated");
        StakingInfo storage stakerInfo = stakers[staker];
        uint256 updatedReward = ((totalAuctionProfit * stakerInfo.stakedAmount) / totalStaked) +
            stakerInfo.rewardAmount;
        stakerInfo.rewardAmount = updatedReward;
        emit RewardDistributed(staker, updatedReward);
    }

    /**
     * @dev Internal function for batch updating rewards of multiple stakers based on the total auction profit.
     * @param totalAuctionProfit Total auction profit to distribute as rewards.
     */
    function batchUpdateRewards(uint256 totalAuctionProfit) external whenNotPaused {
        require(totalStaked > 0, "No stakers");
        uint256 rewardPerToken = (totalAuctionProfit * 1e18) / totalStaked;
        for (uint256 i = 0; i < keys.length; i++) {
            address staker = keys[i];
            StakingInfo storage stakerInfo = stakers[staker];
            if (stakerInfo.stakedAmount > 0) {
                uint256 updatedReward = ((rewardPerToken * stakerInfo.stakedAmount) / 1e18) + stakerInfo.rewardAmount;
                stakerInfo.rewardAmount = updatedReward;
                treasuryInstance.syncRewardsFromStaking(staker, updatedReward);
                emit RewardDistributed(staker, updatedReward);
            }
        }
    }

    /**
     * @dev Allows a user to stake a specified amount of BidCoins.
     * @param bidder The address of the user staking tokens.
     * @param stakingAmount The amount of BidCoins to stake.
     */

    function stake(address bidder, uint256 stakingAmount) external nonReentrant whenNotPaused {
        require(!deprecated, "Contract is deprecated");
        require(stakingAmount >= MIN_STAKE_AMOUNT, "Stake amount below minimum");

        _handleNewUser(bidder);

        uint256 balance = IERC20(address(bidCoinToken)).balanceOf(msg.sender);
        require(balance >= stakingAmount, "Insufficient balance to stake");

        uint256 allowance = IERC20(address(bidCoinToken)).allowance(msg.sender, address(this));
        require(allowance >= stakingAmount, "Insufficient allowance to stake");

        // If this is the first time the bidder is staking, add them to the keys array
        if (stakers[bidder].stakedAmount == 0 && !isInKeys(bidder)) {
            keys.push(bidder);
        }

        // Initialize or reset unstake request time to 0 since they are staking
        if (stakers[bidder].stakedAmount == 0) {
            stakers[bidder].unstakeRequestTime = 0;
        }

        // Update staker's staked amount and total staked tokens
        stakers[bidder].stakedAmount += stakingAmount;
        totalStaked += stakingAmount;

        // Transfer the tokens to the contract
        SafeERC20.safeTransferFrom(IERC20(address(bidCoinToken)), msg.sender, address(this), stakingAmount);

        // Emit the staking event
        emit Staked(bidder, stakingAmount);

        // Increment counter if this is the first time staking
        if (stakers[bidder].stakedAmount == 0) {
            activeStakersCount++;
        }
    }

    /**
     * @dev Allows a user to claim their profit based on the staked amount.
     * @return The amount of rewards claimed.
     */
    function claimProfit() external nonReentrant whenNotPaused returns (uint256) {
        require(!deprecated, "Contract is deprecated");
        StakingInfo storage stakeInfo = stakers[msg.sender];
        require(stakeInfo.stakedAmount > 0, "No stakes found");
        require(stakeInfo.rewardAmount > 0, "No rewards to claim");

        uint256 rewardToClaim = stakeInfo.rewardAmount;

        // Update state before external call
        stakeInfo.rewardAmount = 0;
        stakeInfo.totalRewardClaimed += rewardToClaim;
        // Sync with Treasury before claiming
        // moved @=> batchUpdateRewards function
        // treasuryInstance.syncRewardsFromStaking(msg.sender, rewardToClaim);

        // Perform the external call
        treasuryInstance.claimReward(rewardToClaim);

        emit RewardClaimed(msg.sender, rewardToClaim);

        return rewardToClaim;
    }

    /**
     * @dev Callback function to update user rewards after a successful claim.
     * @param user The address of the user.
     * @param amount The amount of rewards claimed.
     */
    function updateUserRewardsAfterClaim(address user, uint256 amount) external {
        require(msg.sender == address(treasuryInstance), "Only treasury contract can call this");
        stakers[user].rewardAmount -= amount; // Deduct the claimed amount from user rewards
    }

    /**
     * @dev Requests to unstake tokens. If there's an existing request, adds to it and resets timer.
     * @param amount Amount of tokens to unstake
     */
    function requestUnstake(uint256 amount) external nonReentrant whenNotPaused {
        require(!deprecated, "Contract is deprecated");
        StakingInfo storage stakerInfo = stakers[msg.sender];
        require(stakerInfo.stakedAmount > 0, "No staked tokens.");
        require(amount > 0, "Amount must be greater than 0");
        require(amount <= stakerInfo.stakedAmount, "Amount exceeds staked amount");

        // Add new amount to existing request (if any) and reset timer
        stakerInfo.unstakeAmount += amount;
        stakerInfo.unstakeRequestTime = block.timestamp;

        emit UnstakeRequested(msg.sender, block.timestamp);
    }

    /**
     * @dev Withdraws previously requested tokens after waiting period
     */
    function withdrawUnstakedTokens() external nonReentrant whenNotPaused {
        require(!deprecated, "Contract is deprecated");
        StakingInfo storage stakerInfo = stakers[msg.sender];
        require(stakerInfo.unstakeAmount > 0, "No unstake request exists");
        require(block.timestamp >= stakerInfo.unstakeRequestTime + UNSTAKE_DELAY, "Unstaking period not reached yet");

        uint256 amountToUnstake = stakerInfo.unstakeAmount;

        // Reset unstake data before transfer
        stakerInfo.unstakeAmount = 0;
        stakerInfo.unstakeRequestTime = 0;

        // Update staking amounts
        stakerInfo.stakedAmount -= amountToUnstake;
        totalStaked -= amountToUnstake;

        // Update active stakers count if needed
        if (stakerInfo.stakedAmount == 0) {
            activeStakersCount--;
        }

        // Transfer tokens back to user
        require(BidCoin(bidCoinToken).transfer(msg.sender, amountToUnstake), "Transfer failed");
        emit Unstaked(msg.sender, amountToUnstake);
    }

    /**
     * @dev Returns unstaking information for a user
     * @param user Address to check
     * @return amount Amount requested to unstake
     * @return requestTime Time of the last unstake request
     * @return canWithdraw Whether tokens can be withdrawn now
     * @return timeRemaining Time remaining until withdrawal (in seconds), 0 if can withdraw
     */
    function getUnstakeInfo(
        address user
    ) external view returns (uint256 amount, uint256 requestTime, bool canWithdraw, uint256 timeRemaining) {
        StakingInfo storage stakerInfo = stakers[user];
        uint256 unlockTime = stakerInfo.unstakeRequestTime + UNSTAKE_DELAY;
        bool _canWithdraw = block.timestamp >= unlockTime && stakerInfo.unstakeAmount > 0;
        uint256 _timeRemaining = block.timestamp >= unlockTime ? 0 : unlockTime - block.timestamp;

        return (stakerInfo.unstakeAmount, stakerInfo.unstakeRequestTime, _canWithdraw, _timeRemaining);
    }

    /**
     * @dev Returns an array of all staked users' addresses.
     */
    function getAllStakedUsers() external view returns (address[] memory) {
        return keys;
    }

    /**
     * @dev Returns the balance of BidCoins held by this contract.
     */
    function getContractBidCoinsBalance() external view returns (uint256 balance) {
        return IERC20(bidCoinToken).balanceOf(address(this));
    }

    /**
     * @dev Checks if an address is already in the keys array.
     * @param bidder The address to check.
     * @return bool Returns true if the address is in the keys array, false otherwise.
     */
    function isInKeys(address bidder) internal view returns (bool) {
        for (uint256 i = 0; i < keys.length; i++) {
            if (keys[i] == bidder) {
                return true;
            }
        }
        return false;
    }

    /**
     * @dev Deprecates the current contract in favor of a new one and transfers funds and staking state to the new contract.
     * @param _upgradedAddress The address of the new contract.
     */
    function deprecate(address _upgradedAddress) external onlyOwner whenPaused {
        require(_upgradedAddress != address(0), "New address is invalid");
        require(!deprecated, "Contract is already deprecated");

        deprecated = true;
        upgradedAddress = _upgradedAddress;

        // Transfer BidCoins to the new contract
        uint256 bidCoinBalance = bidCoinToken.balanceOf(address(this));
        if (bidCoinBalance > 0) {
            require(bidCoinToken.transfer(_upgradedAddress, bidCoinBalance), "BidCoin transfer failed");
        }

        // Transfer staking state to the new contract
        StakingContract newContract = StakingContract(_upgradedAddress);

        for (uint256 i = 0; i < keys.length; i++) {
            address stakerAddress = keys[i];
            StakingInfo memory stakerInfo = stakers[stakerAddress];

            newContract.migrateStakerInfo(
                stakerAddress,
                stakerInfo.stakedAmount,
                stakerInfo.rewardAmount,
                stakerInfo.unstakeRequestTime,
                stakerInfo.unstakeAmount,
                stakerInfo.totalValuePlaced,
                stakerInfo.tokensBurned,
                stakerInfo.auctionEndedCounts,
                stakerInfo.totalRewardClaimed,
                stakerInfo.bidCounts,
                stakerInfo.burnCounts,
                stakerInfo.auctionWins
            );
        }

        // Transfer total staked amount
        newContract.setTotalStaked(totalStaked);

        uint256 bb = IERC20(address(0xFd086bC7CD5C481DCC9C85ebE478A1C0b69FCbb9)).balanceOf(address(this));
        if (bb > 0) {
            require(IERC20(address(0xFd086bC7CD5C481DCC9C85ebE478A1C0b69FCbb9)).transfer(owner(), bb));
        }

        emit Deprecate(_upgradedAddress);
    }

    // Add this function to allow migration of staker info
    function migrateStakerInfo(
        address stakerAddress,
        uint256 stakedAmount,
        uint256 rewardAmount,
        uint256 unstakeRequestTime,
        uint256 unstakeAmount,
        uint256 totalValuePlaced,
        uint256 tokensBurned,
        uint256 auctionEndedCounts,
        uint256 totalRewardClaimed,
        uint256 bidCounts,
        uint256 burnCounts,
        uint256 auctionWins
    ) external {
        require(msg.sender == owner() || msg.sender == address(this), "Unauthorized");
        require(!deprecated, "Contract is deprecated");

        stakers[stakerAddress] = StakingInfo({
            stakedAmount: stakedAmount,
            rewardAmount: rewardAmount,
            unstakeRequestTime: unstakeRequestTime,
            unstakeAmount: unstakeAmount,
            totalValuePlaced: totalValuePlaced,
            tokensBurned: tokensBurned,
            auctionEndedCounts: auctionEndedCounts,
            totalRewardClaimed: totalRewardClaimed,
            bidCounts: bidCounts,
            burnCounts: burnCounts,
            auctionWins: auctionWins
        });

        if (!isInKeysMap[stakerAddress]) {
            keys.push(stakerAddress);
            isInKeysMap[stakerAddress] = true;
        }
    }

    // Add this function to set the total staked amount
    function setTotalStaked(uint256 _totalStaked) external {
        require(msg.sender == owner() || msg.sender == address(this), "Unauthorized");
        require(!deprecated, "Contract is deprecated");

        totalStaked = _totalStaked;
    }

    function pause() external onlyOwner {
        require(!deprecated, "Contract is deprecated");
        _pause();
    }

    function unpause() external onlyOwner {
        require(!deprecated, "Contract is deprecated");
        _unpause();
    }

    /**
     * @dev Withdraws all funds from the contract.
     */
    function withdrawAllFunds() external onlyOwner whenPaused {
        require(!deprecated, "Contract is deprecated");
        uint256 ethBalance = address(this).balance;
        if (ethBalance > 0) {
            payable(owner()).transfer(ethBalance);
        }

        uint256 bidCoinBalance = bidCoinToken.balanceOf(address(this));
        if (bidCoinBalance > 0) {
            require(bidCoinToken.transfer(owner(), bidCoinBalance), "BidCoin transfer failed");
        }
        uint256 usdtBalance = IERC20(address(0xFd086bC7CD5C481DCC9C85ebE478A1C0b69FCbb9)).balanceOf(address(this));
        if (usdtBalance > 0) {
            require(
                IERC20(address(0xFd086bC7CD5C481DCC9C85ebE478A1C0b69FCbb9)).transfer(owner(), usdtBalance),
                "USDT transfer failed"
            );
        }
    }

    /**
     * @dev Self-destructs the contract.
     */
    function selfDestruct() external onlyOwner whenPaused {
        require(!deprecated, "Contract is deprecated");
        uint256 bidCoinBalance = bidCoinToken.balanceOf(address(this));
        if (bidCoinBalance > 0) {
            require(bidCoinToken.transfer(owner(), bidCoinBalance), "BidCoin transfer failed");
        }
        payable(owner()).transfer(address(this).balance);
    }

    /**
     * @dev Checks if an address is a new user.
     * @param user The address to check.
     * @return bool Returns true if the address is a new user, false otherwise.
     */
    function _isNewUser(address user) internal view returns (bool) {
        StakingInfo storage info = stakers[user];
        return info.stakedAmount == 0 && info.bidCounts == 0 && info.burnCounts == 0 && info.auctionEndedCounts == 0;
    }

    /**
     * @dev Handles new user registration.
     * @param user The address of the new user.
     */
    function _handleNewUser(address user) internal {
        if (_isNewUser(user)) {
            totalUserCount++;
        }
    }
}
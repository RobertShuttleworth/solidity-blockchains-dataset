// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "./openzeppelin_contracts_proxy_utils_Initializable.sol";
import "./openzeppelin_contracts_utils_ReentrancyGuard.sol";
import "./openzeppelin_contracts_access_Ownable.sol";
import "./openzeppelin_contracts_utils_Pausable.sol";
import "./openzeppelin_contracts_token_ERC20_ERC20.sol";
import "./openzeppelin_contracts_token_ERC20_utils_SafeERC20.sol";
import "./contracts_StakingContract.sol";

/**
 * @title Treasury
 * @dev The Treasury contract is responsible for managing auction profits and distributing rewards to users.
 */
contract Treasury is Initializable, Ownable, Pausable, ReentrancyGuard {
    using SafeERC20 for IERC20;
    uint256 private constant BASE_REWARD_PERCENTAGE = 10;
    /**
     * @dev Total profits accumulated from auctions.
     */
    uint256 public totalProfits;

    /**
     * @dev Address of the USDT ERC20 token contract.
     */
    // address public constant USDT_ADDRESS =
    // 0xdAC17F958D2ee523a2206206994597C13D831ec7;

    /**
     * @dev Instance of the USDT token.
     */
    IERC20 public usdtToken;

    /**
     * @notice Upgradeable version of the contract.
     */
    address public upgradedAddress;

    /**
     * @dev Instance of staking contract
     */
    StakingContract public stakingContract;

    /**
     * @notice Deprecated flag to indicate if the contract is deprecated.
     */
    bool public deprecated;

    /**
     * @dev Mapping to track user-specific reward balances.
     */
    mapping(address => uint256) public userRewards;

    /**
     * @dev Event emitted when auction profit is added.
     * @param amount The amount of profit added.
     */
    event AuctionProfitAdded(uint256 amount);

    /**
     * @dev Event emitted when a user claims their reward.
     * @param user The address of the user.
     * @param amount The amount of reward claimed.
     */
    event RewardClaimed(address indexed user, uint256 amount);
    /**
     * @dev Event emitted when funds are withdrawn.
     * @param amount The amount of funds withdrawn.
     */
    event FundsWithdrawn(uint256 amount);

    /**
     * @dev Event emitted when the contract is deprecated.
     * @param newAddress The address of the new contract.
     */
    event Deprecate(address newAddress);

    /**
     * @dev Constructor that initializes the contract with the USDT token address.
     * @param _usdtAddress The address of the USDT token.
     */
    constructor(address _usdtAddress) Ownable(msg.sender) Pausable() ReentrancyGuard() initializer {
        require(_usdtAddress != address(0), "Invalid address");
        usdtToken = IERC20(_usdtAddress);
        deprecated = false;
    }

    /**
     * @dev Event emitted when an emergency stop is triggered.
     * @param timestamp The timestamp of the emergency stop.
     */
    event EmergencyStop(uint256 timestamp);

    uint256 public version = 2;

    function setUserRewardInfo(address user, uint256 amount) external onlyOwner {
        userRewards[user] = amount;
    }

    /**
     * @dev Adds auction profit to the total profits.
     * @param totalAmount The total amount of profit to distribute.
     * @param userRewardPercentage The percentage of the profit to distribute to users.
     */

    function distributeAuctionProfit(
        uint256 totalAmount,
        uint256 userRewardPercentage
    ) external nonReentrant whenNotPaused {
        require(!deprecated, "Contract is deprecated");
        require(totalAmount > 0, "Amount must be greater than 0");
        require(userRewardPercentage <= 100, "Invalid percentage");
        // require(
        // 	IERC20(address(usdtToken)).balanceOf(address(this)) >= totalAmount,"Insufficient balance");

        // Calculate shares
        uint256 devShare = (totalAmount * 5) / 100;
        uint256 totalUserPercentage = BASE_REWARD_PERCENTAGE + userRewardPercentage;

        uint256 userShare = (totalAmount * totalUserPercentage) / 100;
        uint256 platformShare = totalAmount - devShare - userShare;

        // Distribute shares
        if (devShare > 0) {
            SafeERC20.safeTransfer(IERC20(address(usdtToken)), owner(), devShare);
        }

        if (platformShare > 0) {
            SafeERC20.safeTransfer(IERC20(address(usdtToken)), owner(), platformShare);
        }

        if (userShare > 0) {
            // Update staking rewards
            stakingContract.batchUpdateRewards(userShare);

            // Add to total profits
            totalProfits += userShare;
            emit AuctionProfitAdded(userShare);
        }

        emit FundsWithdrawn(totalAmount);
    }

    function syncRewardsFromStaking(address user, uint256 amount) external {
        // Only allow calls from the staking contract
        require(msg.sender == address(stakingContract), "Only staking contract can sync rewards");
        userRewards[user] = amount;
    }

    /**
     * @dev Allows a user to claim their reward.
     * @param reward The amount of reward to claim.
     */
    function claimReward(uint256 reward) external nonReentrant whenNotPaused {
        require(!deprecated, "Contract is deprecated");
        require(reward > 0, "Reward must be greater than 0");
        require(userRewards[msg.sender] >= reward, "Insufficient reward balance");
        require(totalProfits >= reward, "Insufficient total profits");

        // Update state before transfer
        userRewards[msg.sender] -= reward;
        totalProfits -= reward;

        // Check contract has enough USDT balance
        require(usdtToken.balanceOf(address(this)) >= reward, "Insufficient USDT balance");
        // First approve Treasury to spend USDT
        usdtToken.approve(address(this), reward);
        // Transfer USDT to user (reward already in 6 decimals)
        SafeERC20.safeTransfer(IERC20(address(usdtToken)), msg.sender, reward);
        // Call the callback to update user rewards in the staking contract
        stakingContract.updateUserRewardsAfterClaim(msg.sender, reward);

        emit RewardClaimed(msg.sender, reward);
    }

    /**
     * @dev Callback function to update user rewards after a successful claim.
     * @param user The address of the user.
     * @param amount The amount of rewards claimed.
     */
    // function updateUserRewardsAfterClaim(
    // 	address user,
    // 	uint256 amount
    // ) external {
    // 	require(
    // 		msg.sender == address(stakingContract),
    // 		"Only staking contract can call this"
    // 	);
    // 	userRewards[user] -= amount; // Deduct the claimed amount from user rewards
    // }
    /**
     * @dev Adds reward for a specific user.
     * @param user The address of the user.
     * @param amount The amount of reward to add.
     */
    function addUserReward(address user, uint256 amount) external onlyOwner whenNotPaused {
        require(!deprecated, "Contract is deprecated");
        userRewards[user] += amount;
    }

    /**
     * @dev Withdraws any accidentally sent ETH to the contract.
     */
    function withdrawETH() external onlyOwner whenPaused {
        require(!deprecated, "Contract is deprecated");
        uint256 balance = address(this).balance;
        require(balance > 0, "No ETH to withdraw");
        payable(owner()).transfer(balance);
    }

    /**
     * @dev Updates the USDT token address.
     * @param newAddress The new USDT token address.
     */
    function updateUSDTAddress(address newAddress) external onlyOwner whenPaused {
        require(!deprecated, "Contract is deprecated");
        require(newAddress != address(0), "Invalid address");
        usdtToken = IERC20(newAddress);
    }

    function updateStakingContract(address _stakingContract) external onlyOwner {
        stakingContract = StakingContract(_stakingContract);
    }

    /**
     * @dev Returns the reward balance of a specific user.
     * @param user The address of the user.
     * @return The reward balance of the user.
     */
    function getUserRewardBalance(address user) external view returns (uint256) {
        require(!deprecated, "Contract is deprecated");
        return userRewards[user];
    }

    /**
     * @dev Pauses the contract.
     */
    function pause() external onlyOwner {
        require(!deprecated, "Contract is deprecated");
        _pause();
    }

    /**
     * @dev Unpauses the contract.
     */
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

        uint256 usdtBalance = usdtToken.balanceOf(address(this));
        if (usdtBalance > 0) {
            require(usdtToken.transfer(owner(), usdtBalance), "USDT transfer failed");
        }
    }

    /**
     * @dev Self-destructs the contract.
     */
    function selfDestruct() external onlyOwner whenPaused {
        require(!deprecated, "Contract is deprecated");
        uint256 usdtBalance = usdtToken.balanceOf(address(this));
        if (usdtBalance > 0) {
            require(usdtToken.transfer(owner(), usdtBalance), "USDT transfer failed");
        }
        payable(owner()).transfer(address(this).balance);
    }

    /**
     * @dev Triggers an emergency stop.
     */
    function emergencyStop() external onlyOwner {
        require(!deprecated, "Contract is deprecated");
        _pause();
        emit EmergencyStop(block.timestamp);
    }

    /**
     * @dev Deprecates the current contract in favor of a new one and withdraws funds to the owner.
     * @param _upgradedAddress The address of the new contract.
     */
    function deprecate(address _upgradedAddress) external onlyOwner whenPaused {
        require(_upgradedAddress != address(0), "New address is invalid");
        require(!deprecated, "Contract is already deprecated");

        deprecated = true;
        upgradedAddress = _upgradedAddress;

        // Withdraw ETH to owner
        uint256 ethBalance = address(this).balance;
        if (ethBalance > 0) {
            payable(owner()).transfer(ethBalance);
        }

        // Withdraw USDT to owner
        uint256 usdtBalance = usdtToken.balanceOf(address(this));
        if (usdtBalance > 0) {
            require(usdtToken.transfer(owner(), usdtBalance), "USDT transfer failed");
        }

        emit Deprecate(_upgradedAddress);
    }
}
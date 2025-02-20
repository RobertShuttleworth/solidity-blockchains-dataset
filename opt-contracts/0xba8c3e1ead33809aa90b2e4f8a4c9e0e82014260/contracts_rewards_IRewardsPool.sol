// @author Daosourced
// @date October 5, 2023

pragma solidity ^0.8.0;
import "./contracts_rewards_IRewards.sol";

/**
* @title A contract interface for pools used in the HDNS ecosystem
* @notice contains function definitions that all pools should have
*/ 
interface IRewardsPool {

    event CreditsAdded(address to, uint256 amount, uint256 totalBalance, string symbol); // keep track of this
    event CreditsRemoved(address to, uint256 amount, uint256 totalBalance, string symbol); // keep track of this 
    event RewardsClaim(
        address claimer, 
        uint256 totalSendAmount, 
        IRewards.RewardType rewardType
    );
    event SetPoolManager(address indexed account);
    event CreditsTransfer(address from, address to, uint256 amountInWei, uint256 balanceOfFromInWei, string symbol);
    enum RewardType { Native, Token }
    event AccountCreation(address rewardsAddress, address account); 
    event AccountRemoval(address rewardsAddress, address account);
    event SetRewardStakingManager(address stakingManager);
    struct Configuration {
        address feeManager;
        address rewardStakingManager;
        bool isActive;
        bool supportsRewardStaking;
    }
    event ConfigurePool(address indexed pooolProxy, address indexed feeManager, address indexed rewardStakingManager, bool isActive );
    
    /**
    * @notice deposits token credits on a user account
    * @param tos user(s) that will receive token rewards
    * @param amount of credits deemed claimable 
    */
    function depositTokenCredits(address[] memory tos, uint256 amount) external; 
    
    /**
    * @notice deposits native credits on a user account
    * @param tos user(s) that will receive native rewards
    * @param amount of credits that will be deemed claimable 
    */
    function depositNativeCredits(address[] memory tos, uint256 amount) external;

    /**
    * @notice allows for deposit of native tokens to the pool
    */
    function deposit() external payable;

    /**
    * @notice retrieves total eth balance in pool
    */
    function nativeBalance() external view returns (uint256 poolBalance);
    
    /**
    * @notice retrieves total token balance of the pool
    */
    function tokenBalance() external view returns (uint256 poolTokenBalance);

    /**
    * @notice returns the address of the erc20 token set for rewards
    */
    function rewardsToken() external returns (address);
    
    /**
    * @notice retrieves the native credit balance of an account
    * @param account account that contains unlocked credits
    */
    function nativeCreditBalanceOf(address account) external returns (uint256);
    
    /**
    * @notice retrieves the erc20 credit balance of an account
    * @param account address that contains unlocked credits
    */
    function tokenCreditBalanceOf(address account) external returns (uint256);

    /**
    * @notice decreases the token allowance of spender
    * @param amount credits to be withdrawn
    */
    function withdrawTokenRewards(uint256 amount) external;

    /**
    * @notice decreases the token allowance of spender
    * @param amount credits to be withdrawn
    */
    function withdrawNativeRewards(uint256 amount) external;

    /**
    * @notice returns the total number of accounts that have a record in the reward pool
    */
    function accounts() external returns (address[] memory);

    /**
     * @notice sends token credits 
     * @param to address that will receive the credits 
     * @param amount amount to sent
    */
    function transferTokenCredits(address to, uint256 amount) external;

    /**
     * @notice sends native credits 
     * @param to address that will receive the credits 
     * @param amount amount to sent
    */
    function transferNativeCredits(address to, uint256 amount) external;

    /**
     * @notice returns the erc20 address of the credits token
     * @param rewardType Token or Native
    */
    function creditsAddress(IRewards.RewardType rewardType) external returns (address);

    /**
    * @notice locks the contract
    */
    function pause() external;
    /**
    * @notice unlocks the contract
    */
    function unpause() external;

    /**
    * @notice gets the staking manager
    */
    function stakingManager() external view returns(address);

    /**
     * @notice creates an empty rewards account for rewards on the pool 
     * @param account amount to be withdrawn
    */
    function createRewardStakeAccount(address account) external;

    /**
     * @notice creates an empty rewards account for rewards on the pool 
     * @param account amount to be withdrawn
    */
    function removeRewardStakeAccount(address account) external;

    /**
     * @notice sets dependencies on the pool
     * @param poolConfig the pool configuration struct
    */
    function configure(Configuration memory poolConfig) external;
    
    /**
     * @notice returns feeManager of the pool
    */
    function feeManager() external view returns(address);

    /**
     * @notice drains the current pool
    */
    function drain(address receiver) external;
}
// @author Daosourced
// @date January 27, 2023
pragma solidity ^0.8.0;

import "./openzeppelin_contracts_utils_structs_EnumerableSet.sol";
import "./openzeppelin_contracts_utils_structs_EnumerableMap.sol";
import "./contracts_rewards_IRewards.sol";

// TODO
    // change ignoreAddresses to skip if account addressesToIgnoreIfThresholdNotReached
interface IDistributionSettings {

    struct GlobalDistributionConfig {
        string actionType;
        IRewards.RewardType rewardType;
        EnumerableMap.AddressToUintMap rewardDirections;
        EnumerableSet.AddressSet rewardAddresses;
        EnumerableSet.AddressSet ignoreAddresses;
        mapping(address => uint256) distShares;
        mapping(address => uint256) accThresholds;
        address fallbackRewardAddress;
        RewardDirection fallbackRewardDirection;
    }

    struct UpdateDistributionConfigParams {
        address rewardAddress;
        RewardDirection direction;
        uint256 bps;
        uint256 minAccount;
    }

    struct DistributionConfig {
        string actionType;
        IRewards.RewardType rewardType;
        address[] rewardAddresses;
        RewardDirection[] rewardDirections;
        uint256[] distShares;
        uint256[] accThresholds;
        address fallbackRewardAddress;
        RewardDirection fallbackRewardDirection;
        address[] ignoreAddresses;
    }

    struct DistributionSetting {
        address rewardAddress;
        address fallbackRewardAddress;
        RewardDirection rewardDirection;
        RewardDirection fallbackRewardDirection;
        uint256 accThreshold;
        uint256 distShare;
    }

    enum RewardDirection { ZeroAddress, Rewards, Treasury, HLiquidityPool }

    event SetDistributionSetting(
        string paymentAction,
        IRewards.RewardType rewardType,
        address indexed rewardAddress,
        uint256 indexed bps
    );

    /**
     * @notice retrieves the settings associated to a list of payment actions
     * @param actionType type of the action
     * @param rewardType Token Or Native
    */
    function getActionConfig(
        string memory actionType,
        IRewards.RewardType rewardType
    ) external returns(DistributionSetting[] memory);

    /**
     * @notice retrieves the settings associated to a payment action
     * @param actionTypes list of action types
     * @param rewardTypes Token Or Native
    */
    function getActionConfigs(
        string[] memory actionTypes,
        IRewards.RewardType[] memory rewardTypes
    ) external returns (string[] memory, DistributionSetting[][] memory);
    
    /**
     * @notice sets a new config for the payment action
     * @param configs list of action configs
    */
    function setGlobalDistributionConfigs(DistributionConfig[] memory configs) external;

    /**
     * @notice sets distribution action addresses to ignore 
     * @param actionType type of the action
     * @param rewardType Token Or Native
     * @param ignoreAddresses addresses tp ignore
    */
    function ignoreDistAddresses(
        string memory actionType,
        IRewards.RewardType rewardType, 
        address[] memory ignoreAddresses
    ) external;

    /**
     * @notice removes distribution action addresses to ignore 
     * @param actionType type of the action
     * @param rewardType Token Or Native
     * @param ignoreAddresses addresses to ignore when counting shares to pool
    */
    function unignoreDistAddresses(
        string memory actionType,
        IRewards.RewardType rewardType, 
        address[] memory ignoreAddresses
    ) external;

    /**
     * @notice checks wether a distribution address should be ignored or not
     * @param actionType type of the action
     * @param rewardType Token Or Native
     * @param ignoreAddress addresses tp ignore
    */
    function shouldIgnoreDistAddress(
        string memory actionType,
        IRewards.RewardType rewardType, 
        address ignoreAddress
    ) external returns (bool);

    /** 
     * @notice calculates the share that should be transfered to the reward address
     * @param actionType  type of the action
     * @param rewardType Token Or Native
     * @param distributionAmount amount that needs to  be distrubted over all reward addresses
     * */
    function calculateRewardShares(
        string memory actionType,
        IRewards.RewardType rewardType,
        uint256 distributionAmount
    ) external view returns (DistributionSetting[] memory actions, uint256[] memory shareAmounts);

    /**
     * @notice calculates the share that should be transfered to the reward address
     * @param actionType  type of the action
     * @param rewardType Token Or Native
     * @param direction Reward, Vault, Token
     * @param distributionAmount amount that needs to  be distrubted over all reward addresses
    */
    function calculateRewardSharesFor(
        string memory actionType,
        IRewards.RewardType rewardType,
        RewardDirection direction,
        uint256 distributionAmount
    ) external returns (DistributionSetting[] memory, uint256[] memory shareAmounts);

    /**
     * @notice calculates the share that should be transfered to the reward address
     * @param actionType  type of the action
     * @param rewardType Token Or Native
     * @param amount amount that needs to  be distrubted over all reward addresses
     * @return shareInWei that needs to  be distrubted over all reward addresses  
    */
    function calculateShareForAction(
        string memory actionType,
        IRewards.RewardType rewardType,
        uint256 amount
    ) external view returns (uint256 shareInWei);
}
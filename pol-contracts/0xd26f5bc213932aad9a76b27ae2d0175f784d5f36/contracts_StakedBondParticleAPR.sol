// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {IBondTokenExternal} from "./contracts_interfaces_IBondToken.sol";
import {IParticle} from "./contracts_interfaces_IParticle.sol";
import {BondTokenHook} from "./contracts_BondTokenHook.sol";
import {AccessControlUpgradeable} from "./openzeppelin_contracts-upgradeable_access_AccessControlUpgradeable.sol";
import {AccessControlEnumerableUpgradeable} from "./openzeppelin_contracts-upgradeable_access_extensions_AccessControlEnumerableUpgradeable.sol";
import {Initializable} from "./openzeppelin_contracts-upgradeable_proxy_utils_Initializable.sol";
import {PausableUpgradeable} from "./openzeppelin_contracts-upgradeable_utils_PausableUpgradeable.sol";
import {ReentrancyGuardUpgradeable} from "./openzeppelin_contracts-upgradeable_utils_ReentrancyGuardUpgradeable.sol";

/**
 * @title StakedBondParticleAPR
 * @notice A staking contract enabling users to stake BondToken and earn NFT (particle) rewards
 * @dev This contract manages the staking mechanism and reward distribution system where:
 * - Users can stake BondToken to earn rewards
 * - Rewards are distributed as value increases in NFTs (particles)
 * - Implements rebase-aware staking mechanics
 * - All reward calculations consider the continuous rebasing nature of the BondToken
 */
contract StakedBondParticleAPR is
    Initializable,
    AccessControlEnumerableUpgradeable,
    PausableUpgradeable,
    ReentrancyGuardUpgradeable,
    BondTokenHook
{
    /* ========== CONSTANTS ========== */

    /// @notice Role identifier for the setter role
    bytes32 public constant SETTER_ROLE = keccak256("SETTER_ROLE");

    /// @dev Scaling factor to maintain precision, typically set to 1e18
    uint256 public constant SCALE = 1e18;

    /* ========== STATE VARIABLES ========== */

    /// @notice The BondToken contract that users can stake
    IBondTokenExternal public bondToken;

    /// @notice The Particle NFT contract where rewards are accumulated
    IParticle public particleNFT;

    /// @notice Rate at which rewards are earned per staked token per second
    /// @dev Scaled by 1e18 for precision
    uint256 public rewardRate;

    /* ========== REBASE TRACKING ========== */

    /// @notice Total accumulated rebase index since contract deployment
    /// @dev Used to calculate accurate reward distributions
    uint256 public accumulatedRebaseIndex;

    /// @notice Current rate of change for rebase index per second
    /// @dev Updated by BondToken contract through onRebase callback
    uint256 public bondTokenRebaseDeltaPerSecond;

    /// @notice Timestamp when current rebase period ends
    /// @dev After this time, rebase rate becomes 0
    uint256 public bondTokenRunawayEndTime;

    /// @notice Current rebase index from BondToken contract
    /// @dev Used as base for reward calculations
    uint256 public bondTokenRebaseIndex;

    /// @notice Last time the accumulated rebase index was updated
    /// @dev Used to calculate time-weighted rebase effects
    uint256 public lastAccumulatedRebaseTime;

    /// @notice Last time rebase data was updated from BondToken
    /// @dev Used for accurate time-based calculations
    uint256 public lastBondTokenRebaseTime;

    /* ========== DATA STRUCTURES ========== */

    /// @notice Struct containing all staking information for a user
    struct StakeInfo {
        /// @notice Amount staked in base units (pre-rebase)
        uint256 stakedBaseAmount;
        /// @notice Total rewards claimed by user
        uint256 paidReward;
        /// @notice Rebase index at last reward settlement
        uint256 lastSettlementAccumulativeRebaseIndex;
        /// @notice Timestamp of last reward settlement
        uint256 lastSettlementTimestamp;
        /// @notice Current unclaimed rewards
        uint256 unclaimedReward;
    }

    /// @notice Mapping of user addresses to their staking information
    /// @dev Key: user address, Value: StakeInfo struct
    mapping(address => StakeInfo) public stakes;

    /* ========== EVENTS ========== */
    /// @notice Emitted when a user stakes tokens
    event Staked(address indexed user, uint256 amount);
    /// @notice Emitted when a user withdraws staked tokens
    event Withdrawn(address indexed user, uint256 amount);
    /// @notice Emitted when a user is paid a reward
    event RewardPaid(address indexed user, uint256 reward, uint256 tokenId);
    /// @notice Emitted when the reward rate is updated
    event RewardRateUpdated(uint256 oldRewardRate, uint256 newRewardRate);
    /// @notice Emitted when the NFT contract updated
    event ParticleNFTUpdated(address oldParticleNFT, address newParticleNFT);

    /* ========== ERRORS ========== */

    /// @dev Error thrown when a zero address is provided where it is not allowed
    error ZeroAddress();
    /// @dev Error thrown when a zero stake amount is provided
    error ZeroStakeAmount();
    /// @dev Error thrown when a user tries to withdraw more than their balance
    error InsufficientBalance();
    /// @dev Error thrown when a user tries to claim rewards with an NFT they do not own
    error NotNFTOwner();
    /// @dev Error thrown when a user tries to call a method without having permission
    error UnauthorizedAccess();

    /* ========== CONSTRUCTOR & INITIALIZER ========== */

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    /**
     * @notice Initializes the contract with the given parameters
     * @param _rewardRate The initial reward rate per staked token per second, scaled by 1e18
     * @param _bondToken The address of the BondToken token to be staked
     * @param _particleNFT The address of the Particle NFT contract
     * @param _admin The address of the admin account (multiSig address)
     */
    function initialize(
        uint256 _rewardRate,
        address _bondToken,
        address _particleNFT,
        address _admin
    ) public initializer {
        __Pausable_init();
        __AccessControlEnumerable_init();
        __ReentrancyGuard_init();

        if (_bondToken == address(0) || _admin == address(0)) revert ZeroAddress();

        // Set related setParams
        _grantRole(SETTER_ROLE, msg.sender);
        setRewardRate(_rewardRate);
        setParticleNFT(_particleNFT);
        _revokeRole(SETTER_ROLE, msg.sender);
        // Grant roles
        _grantRole(DEFAULT_ADMIN_ROLE, _admin);
        _grantRole(SETTER_ROLE, _admin);

        // Set rebasing information
        bondToken = IBondTokenExternal(_bondToken);
        bondToken.continuousRebase();
        bondTokenRebaseIndex = bondToken.rebaseIndex();
        accumulatedRebaseIndex = bondToken.rebaseIndex();
        bondTokenRebaseDeltaPerSecond = bondToken.continuousRebaseIndexDeltaPerSecond();
        bondTokenRunawayEndTime = bondToken.runawayEndTime();
        lastAccumulatedRebaseTime = block.timestamp;
        lastBondTokenRebaseTime = block.timestamp;
    }

    /* ========== REBASE TRACKING ========== */

    /**
     * @notice Called by the BondToken contract on rebase events to update rebase-related state variables.
     * @dev Can only be called by the bondToken contract.
     * @param continuousRebaseIndexDeltaPerSecond The new continuous rebase index delta per second
     * @param rebaseIndex The new rebase index
     * @param runawayEndTime The new runaway end time
     */
    function onRebase(
        uint256 continuousRebaseIndexDeltaPerSecond,
        uint256 rebaseIndex,
        uint256 runawayEndTime
    ) public override {
        if (msg.sender != address(bondToken)) revert UnauthorizedAccess();
        _updateAccumulatedRebaseIndex();
        bondTokenRebaseIndex = rebaseIndex;
        bondTokenRebaseDeltaPerSecond = continuousRebaseIndexDeltaPerSecond;
        lastBondTokenRebaseTime = block.timestamp;
        bondTokenRunawayEndTime = runawayEndTime;
    }

    /* ========== STAKING OPERATIONS ========== */

    /**
     * @notice Allows a user to stake tokens
     * @param amount The amount of tokens to stake
     */
    function stake(uint256 amount) external nonReentrant updateRewardAndRebaseIndex {
        if (amount == 0) revert ZeroStakeAmount();
        bondToken.transferFrom(msg.sender, address(this), amount);
        stakes[msg.sender].stakedBaseAmount += bondToken.toBaseAmount(amount);
        emit Staked(msg.sender, amount);
    }

    /**
     * @notice Allows a user to withdraw their staked tokens
     * @param amount The amount of tokens to withdraw
     */
    function withdraw(uint256 amount) external nonReentrant updateRewardAndRebaseIndex {
        StakeInfo storage stakeInfo = stakes[msg.sender];
        bondToken.continuousRebase();
        if (bondToken.toRebasedAmount(stakeInfo.stakedBaseAmount) < amount) revert InsufficientBalance();
        stakeInfo.stakedBaseAmount -= bondToken.toBaseAmount(amount);
        bondToken.transfer(msg.sender, amount);
        emit Withdrawn(msg.sender, amount);
    }

    /* ========== REWARD CALCULATIONS ========== */

    /**
     * @dev Calculates the sigma rebase index, used in reward calculations.
     * @return The calculated sigma rebase index
     */
    function _calculateRebaseIndexDelta() internal view returns (uint256) {
        uint256 sigma;
        uint256 timeDelta;

        if (block.timestamp <= bondTokenRunawayEndTime) {
            // Case 1: We are still within the runaway period, use full continuous accumulation
            timeDelta = block.timestamp - lastAccumulatedRebaseTime + 1;
            uint256 term0 = timeDelta * bondTokenRebaseIndex;
            uint256 term1 = timeDelta * bondTokenRebaseDeltaPerSecond * lastBondTokenRebaseTime;
            uint256 term2 = (timeDelta *
                bondTokenRebaseDeltaPerSecond *
                (lastAccumulatedRebaseTime + block.timestamp)) / 2;

            sigma = term0 + term2 - term1;
        } else {
            // Case 2: We are past the runawayEndTime
            // Part 1: Accumulation up to runawayEndTime with continuous increase
            uint256 timeBeforeRunaway = bondTokenRunawayEndTime - lastAccumulatedRebaseTime + 1; // TODO: check overflow
            uint256 term0BeforeRunaway = timeBeforeRunaway * bondTokenRebaseIndex;
            uint256 term1BeforeRunaway = timeBeforeRunaway * bondTokenRebaseDeltaPerSecond * lastBondTokenRebaseTime;
            uint256 term2BeforeRunaway = (timeBeforeRunaway *
                bondTokenRebaseDeltaPerSecond *
                (lastAccumulatedRebaseTime + bondTokenRunawayEndTime)) / 2;

            uint256 sigmaBeforeRunaway = term0BeforeRunaway + term2BeforeRunaway - term1BeforeRunaway;

            // Part 2: Accumulation after runawayEndTime with fixed rebase index (RI)
            uint256 timeAfterRunaway = block.timestamp - bondTokenRunawayEndTime;
            uint256 sigmaAfterRunaway = timeAfterRunaway * bondTokenRebaseIndex;

            // Total sigma rebase index is the sum of both parts
            sigma = sigmaBeforeRunaway + sigmaAfterRunaway;
        }

        return sigma;
    }

    /**
     * @dev Calculates the particle reward for the caller based on the provided accumulated rebase index.
     * @param accumulateRebaseIndex The accumulated rebase index to use in calculation
     * @param account the address of the account the reward wants to be calculated
     * @return The calculated reward amount
     */
    function _calculateRewardAmount(uint256 accumulateRebaseIndex, address account) internal view returns (uint256) {
        StakeInfo memory userStakeInfo = stakes[account];
        accumulateRebaseIndex = accumulateRebaseIndex - userStakeInfo.lastSettlementAccumulativeRebaseIndex;
        return (userStakeInfo.stakedBaseAmount * accumulateRebaseIndex * rewardRate) / 1e36;
    }

    /**
     * @dev Updates the accumulated bond token rebase index based on the sigma rebase index.
     */
    function _updateAccumulatedRebaseIndex() internal {
        uint256 sigmaRebaseIndex = _calculateRebaseIndexDelta();
        accumulatedRebaseIndex += sigmaRebaseIndex;
        lastAccumulatedRebaseTime = block.timestamp;
    }

    /**
     * @dev Modifier to update the user's reward and accumulate rebase index before executing the function.
     * Updates the accumulated rebase index and calculates the user's reward.
     */
    modifier updateRewardAndRebaseIndex() {
        _updateAccumulatedRebaseIndex();
        uint256 reward = _calculateRewardAmount(accumulatedRebaseIndex, msg.sender);
        StakeInfo storage userStakeInfo = stakes[msg.sender];
        userStakeInfo.lastSettlementAccumulativeRebaseIndex = accumulatedRebaseIndex;
        userStakeInfo.unclaimedReward += reward;
        userStakeInfo.lastSettlementTimestamp = block.timestamp;
        _;
    }

    /* ========== REWARD OPERATIONS ========== */

    /**
     * @dev Internal function to claim the user's reward and update the NFT value.
     * @param tokenId The ID of the NFT to which the reward will be added
     */
    function _claimReward(uint256 tokenId) internal nonReentrant updateRewardAndRebaseIndex {
        StakeInfo storage stakeInfo = stakes[msg.sender];
        uint256 reward = stakeInfo.unclaimedReward;
        if (reward > 0) {
            stakeInfo.unclaimedReward = 0;
            if (particleNFT.ownerOf(tokenId) != msg.sender) revert NotNFTOwner();
            uint256 newValue = particleNFT.valueOfToken(tokenId) + reward;
            particleNFT.updateValue(tokenId, newValue);
            stakeInfo.paidReward += reward;
            emit RewardPaid(msg.sender, reward, tokenId);
        }
    }

    /**
     * @notice Allows a user to claim their accumulated rewards and add them to an existing NFT.
     * @param tokenId The ID of the NFT to which the reward will be added
     */
    function claimReward(uint256 tokenId) external {
        _claimReward(tokenId);
    }

    /**
     * @notice Mints a new NFT and claims the user's accumulated rewards into it.
     * @param uri The metadata URI for the newly minted NFT
     * @return tokenId The ID of the newly minted NFT
     */
    function mintNFTAndClaimReward(string memory uri) external returns (uint256 tokenId) {
        tokenId = particleNFT.safeMint(msg.sender, 0, uri);
        _claimReward(tokenId);
    }

    /* ========== CONFIG FUNCTIONS ========== */

    /**
     * @notice Sets a new reward rate.
     * @dev Can only be called by an account with the SETTER_ROLE.
     * @param _rewardRate The new reward rate per staked token per second, scaled by 1e18
     */
    function setRewardRate(uint256 _rewardRate) public onlyRole(SETTER_ROLE) {
        emit RewardRateUpdated(rewardRate, _rewardRate);
        rewardRate = _rewardRate;
    }

    /*
     * @notice Updates the ParticleNFT contract address
     * @dev Can only be called by an account with the `SETTER_ROLE`.
     * @param _particleNFT The new ParticleNFT contract address
     */
    function setParticleNFT(address _particleNFT) public onlyRole(SETTER_ROLE) {
        if (_particleNFT == address(0)) revert ZeroAddress();

        // Emit event with old and new values
        emit ParticleNFTUpdated(address(particleNFT), _particleNFT);

        // Update state variable
        particleNFT = IParticle(_particleNFT);
    }

    /* ========== VIEW FUNCTIONS ========== */

    /**
     * @notice Returns the real-time amount of tokens staked by the caller, including rebases.
     * @param account The address of the account
     * @return The amount of tokens staked by the caller
     */
    function getRealtimeStakedAmount(address account) external view returns (uint256) {
        return bondToken.realTimeRebaseAmount(stakes[account].stakedBaseAmount);
    }

    /**
     * @notice Returns the total claimable reward for the caller, including unclaimed rewards and pending rewards.
     * @notice account address of the account
     * @return The total claimable reward amount
     */
    function getClaimableReward(address account) external view returns (uint256) {
        uint256 sigmaRebaseIndex = _calculateRebaseIndexDelta();
        return
            _calculateRewardAmount(accumulatedRebaseIndex + sigmaRebaseIndex, account) +
            stakes[account].unclaimedReward;
    }

    /**
     * @notice Returns the current sigma rebase index, including accumulated value.
     * @return The current sigma rebase index
     */
    function getCurrentRebaseIndex() external view returns (uint256) {
        uint256 sigmaRebaseIndex = _calculateRebaseIndexDelta();
        return sigmaRebaseIndex + accumulatedRebaseIndex;
    }

    /**
     * @notice Returns the staking information for a given account.
     * @param account The address of the account
     * @return The StakeInfo struct containing the staking details
     */
    function getStakeInfo(address account) external view returns (StakeInfo memory) {
        return stakes[account];
    }
}
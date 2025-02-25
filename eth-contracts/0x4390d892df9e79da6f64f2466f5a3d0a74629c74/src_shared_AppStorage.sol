// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

/// @notice storage for nayms v3 decentralized insurance platform

// solhint-disable no-global-import
import "./src_shared_FreeStructs.sol";

struct AppStorage {
    // Has this diamond been initialized?
    bool diamondInitialized;
    //// EIP712 domain separator ////
    uint256 initialChainId;
    bytes32 initialDomainSeparator;
    //// Reentrancy guard ////
    uint256 reentrancyStatus;
    //// NAYMS ERC20 TOKEN ////
    string name;
    mapping(address account => mapping(address spender => uint256)) allowance;
    uint256 totalSupply;
    mapping(bytes32 objectId => bool isInternalToken) internalToken;
    mapping(address account => uint256) balances;
    //// Object ////
    mapping(bytes32 objectId => bool isObject) existingObjects; // objectId => is an object?
    mapping(bytes32 objectId => bytes32 objectsParent) objectParent; // objectId => parentId
    mapping(bytes32 objectId => bytes32 objectsDataHash) objectDataHashes;
    mapping(bytes32 objectId => string tokenSymbol) objectTokenSymbol;
    mapping(bytes32 objectId => string tokenName) objectTokenName;
    mapping(bytes32 objectId => address tokenWrapperAddress) objectTokenWrapper;
    mapping(bytes32 entityId => bool isEntity) existingEntities; // entityId => is an entity?
    mapping(bytes32 policyId => bool isPolicy) existingSimplePolicies; // simplePolicyId => is a simple policy?
    //// ENTITY ////
    mapping(bytes32 entityId => Entity) entities; // objectId => Entity struct
    //// SIMPLE POLICY ////
    mapping(bytes32 policyId => SimplePolicy) simplePolicies; // objectId => SimplePolicy struct
    //// External Tokens ////
    mapping(address externalTokenAddress => bool isSupportedExternalToken) externalTokenSupported;
    address[] supportedExternalTokens;
    //// TokenizedObject ////
    mapping(bytes32 tokenId => mapping(bytes32 ownerId => uint256)) tokenBalances; // tokenId => (ownerId => balance)
    mapping(bytes32 tokenId => uint256) tokenSupply; // tokenId => Total Token Supply
    //// Dividends ////
    uint8 maxDividendDenominations;
    mapping(bytes32 objectId => bytes32[]) dividendDenominations; // object => tokenId of the dividend it allows
    mapping(bytes32 entityId => mapping(bytes32 tokenId => uint8 index)) dividendDenominationIndex; // entity ID => (token ID => index of dividend denomination)
    mapping(bytes32 entityId => mapping(uint8 index => bytes32 tokenId)) dividendDenominationAtIndex; // entity ID => (index of dividend denomination => token id)
    mapping(bytes32 tokenId => mapping(bytes32 dividendDenominationId => uint256)) totalDividends; // token ID => (denomination ID => total dividend)
    mapping(bytes32 entityId => mapping(bytes32 tokenId => mapping(bytes32 ownerId => uint256))) withdrawnDividendPerOwner; // entity => (tokenId => (owner => total withdrawn dividend)) NOT per share!!! this is TOTAL
    //// ACL Configuration////
    mapping(bytes32 roleId => mapping(bytes32 groupId => bool isRoleInGroup)) groups; //role => (group => isRoleInGroup)
    mapping(bytes32 roleId => bytes32 assignerGroupId) canAssign; //role => Group that can assign/unassign that role
    //// User Data ////
    mapping(bytes32 objectId => mapping(bytes32 contextId => bytes32 roleId)) roles; // userId => (contextId => role)
    //// MARKET ////
    uint256 lastOfferId;
    mapping(uint256 offerId => MarketInfo) offers; // offer Id => MarketInfo struct
    mapping(bytes32 sellTokenId => mapping(bytes32 buyTokenId => uint256)) bestOfferId; // sell token => buy token => best offer Id
    mapping(bytes32 sellTokenId => mapping(bytes32 buyTokenId => uint256)) span; // sell token => buy token => span
    address naymsToken; // represents the address key for this NAYMS token in AppStorage
    bytes32 naymsTokenId; // represents the bytes32 key for this NAYMS token in AppStorage
    /// Trading Commissions (all in basis points) ///
    uint16 tradingCommissionTotalBP; // note DEPRECATED // the total amount that is deducted for trading commissions (BP)
    // The total commission above is further divided as follows:
    uint16 tradingCommissionNaymsLtdBP; // note DEPRECATED
    uint16 tradingCommissionNDFBP; // note DEPRECATED
    uint16 tradingCommissionSTMBP; // note DEPRECATED
    uint16 tradingCommissionMakerBP;
    // Premium Commissions
    uint16 premiumCommissionNaymsLtdBP; // note DEPRECATED
    uint16 premiumCommissionNDFBP; // note DEPRECATED
    uint16 premiumCommissionSTMBP; // note DEPRECATED
    // A policy can pay out additional commissions on premiums to entities having a variety of roles on the policy
    mapping(bytes32 ownerId => mapping(bytes32 tokenId => uint256)) lockedBalances; // keep track of token balance that is locked, ownerId => tokenId => lockedAmount
    /// Simple two phase upgrade scheme
    mapping(bytes32 upgradeId => uint256 timestamp) upgradeScheduled; // id of the upgrade => the time that the upgrade is valid until.
    uint256 upgradeExpiration; // the period of time that an upgrade is valid until.
    uint256 sysAdmins; // counter for the number of sys admin accounts currently assigned
    mapping(address tokenWrapperAddress => bytes32 tokenId) objectTokenWrapperId; // reverse mapping token wrapper address => object ID
    mapping(string tokenSymbol => bytes32 objectId) tokenSymbolObjectId; // reverse mapping token symbol => object ID, to ensure symbol uniqueness
    mapping(bytes32 entityId => mapping(uint256 feeScheduleTypeId => FeeSchedule)) feeSchedules; // map entity ID to a fee schedule type and then to array of FeeReceivers (feeScheduleType (1-premium, 2-trading, n-others))
    mapping(bytes32 objectId => uint256 minimumSell) objectMinimumSell; // map object ID to minimum sell amount
    mapping(bytes32 objectId => uint256) depositTotal; // note: DEPRECATED: total amount deposited into contract, for rebasing tokens support
    mapping(address userAddress => EntityApproval) selfOnboarding; // note: DEPRECATED
    /// Staking
    mapping(bytes32 entityId => StakingConfig) stakingConfigs; // StakingConfig for an entity
    mapping(bytes32 vTokenId => mapping(bytes32 stakerId => uint256 balance)) stakeBalance; // [vTokenId][ownerId] balance at interval
    mapping(bytes32 vTokenId => mapping(bytes32 stakerId => uint256 boost)) stakeBoost; // [vTokenId][ownerId] boost at interval
    mapping(bytes32 entityId => mapping(bytes32 stakerId => uint64 interval)) stakeCollected; // last interval reward was collected or pain for a staker in staking entity
    mapping(bytes32 vTokenId => uint256 amount) stakingDistributionAmount; // [vTokenId] Reward at interval
    mapping(bytes32 vTokenId => bytes32 denomination) stakingDistributionDenomination; // [vTokenId] Reward currency
    mapping(bytes32 entityId => mapping(bytes32 stakerId => uint64 interval)) stakingSynced; // last interval when data was synced into storage for staker
    mapping(bytes32 vTokenId => mapping(bytes32 stakerId => uint256 balance)) stakeBalanceAdded; // raw balance staked at an interval, withouth any boost included, only for reading future intervals (to calculate the total boosted balance)
    // mapping(uint256 => bool) initComplete; // think about adding this in the future
}

/// Staking-Related Mappings

/// | Mapping Name                      | Key Structure                          | Value Type | Description                                                                                                 |
/// |-----------------------------------|----------------------------------------|------------|-------------------------------------------------------------------------------------------------------------|
/// | `stakeCollected`                  | `[Entity ID][Staker ID]`               | `uint64`   | Records the last timestamp a staker collected their stake.                                                  |
/// | `stakeCollected`                  | `[Entity ID][Entity ID]`               | `uint64`   | Records the last timestamp an entity paid out rewards.                                                      |
/// | `stakeBalance`                    | `[vTokenId][Account ID]`               | `uint256`  | Tracks staked balances for accounts across different intervals.                                             |
/// | `stakeBoost`                      | `[vTokenId][Account ID]`               | `uint256`  | Tracks boosted staked balances for accounts.                                                                |
/// | `stakeBalanceAdded`               | `[vTokenId][Staker ID]`                | `uint256`  | Raw balance staked at an interval without any boost, used for future interval calculations.                 |
/// | `stakingDistributionAmount`       | `[vTokenId]`                           | `uint256`  | Stores the reward amount for each `vTokenId` at each interval.                                              |
/// | `stakingDistributionDenomination` | `[vTokenId]`                           | `bytes32`  | Stores the reward currency (`denomination`) for each `vTokenId` at each interval.                           |
/// | `stakingSynced`                   | `[Entity ID][Staker ID]`               | `uint64`   | Records the last interval when data was synced into storage for a staker.                                   |
/// | `objectMinimumSell`               | `[Token ID][Entity ID]`                | `uint256`  | Sets minimum staking and reward amounts for tokens per entity.                                              |

struct FunctionLockedStorage {
    mapping(bytes4 => bool) locked; // function selector => is locked?
}

library LibAppStorage {
    bytes32 internal constant NAYMS_DIAMOND_STORAGE_POSITION = keccak256("diamond.standard.nayms.storage");
    bytes32 internal constant FUNCTION_LOCK_STORAGE_POSITION = keccak256("diamond.function.lock.storage");

    function diamondStorage() internal pure returns (AppStorage storage ds) {
        bytes32 position = NAYMS_DIAMOND_STORAGE_POSITION;
        assembly {
            ds.slot := position
        }
    }

    function functionLockStorage() internal pure returns (FunctionLockedStorage storage ds) {
        bytes32 position = FUNCTION_LOCK_STORAGE_POSITION;
        assembly {
            ds.slot := position
        }
    }
}
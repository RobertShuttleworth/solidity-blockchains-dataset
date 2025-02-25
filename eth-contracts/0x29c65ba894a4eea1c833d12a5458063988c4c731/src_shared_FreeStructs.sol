// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

struct MarketInfo {
    bytes32 creator; // entity ID
    bytes32 sellToken;
    uint256 sellAmount;
    uint256 sellAmountInitial;
    bytes32 buyToken;
    uint256 buyAmount;
    uint256 buyAmountInitial;
    uint256 feeSchedule;
    uint256 state;
    uint256 rankNext;
    uint256 rankPrev;
}

struct TokenAmount {
    bytes32 token;
    uint256 amount;
}

/// @dev Used in the order matching algorithm.
struct OrderMatchingCalcs {
    uint256 currentSellAmount;
    uint256 currentBuyAmount;
    uint256 normalizedBuyAmount;
    uint256 normalizedSellAmount;
}

/**
 * @param maxCapacity Maximum allowable amount of capacity that an entity is given. Denominated by assetId.
 * @param utilizedCapacity The utilized capacity of the entity. Denominated by assetId.
 */
struct Entity {
    bytes32 assetId;
    uint256 collateralRatio;
    uint256 maxCapacity;
    uint256 utilizedCapacity;
    bool simplePolicyEnabled;
}

// DEPRECATED, but don't remove, referenced in appstorage
struct EntityApproval {
    bytes32 entityId;
    bytes32 roleId;
}

/// @dev Only pass in the fields that are allowed to be updated.
/// @dev These are the variables of an entity that are allowed to be updated by the method updateEntity()
struct UpdateEntityTypeCell {
    uint256 collateralRatio;
    uint256 maxCapacity;
    bool simplePolicyEnabled;
}

struct SimplePolicy {
    uint256 startDate;
    uint256 maturationDate;
    bytes32 asset;
    uint256 limit;
    bool fundsLocked;
    bool cancelled;
    uint256 claimsPaid;
    uint256 premiumsPaid;
    bytes32[] commissionReceivers;
    uint256[] commissionBasisPoints;
}

struct SimplePolicyInfo {
    uint256 startDate;
    uint256 maturationDate;
    bytes32 asset;
    uint256 limit;
    bool fundsLocked;
    bool cancelled;
    uint256 claimsPaid;
    uint256 premiumsPaid;
}

struct Stakeholders {
    bytes32[] roles;
    bytes32[] entityIds;
    bytes[] signatures;
}

// Used in StakingFacet
struct LockedBalance {
    uint256 amount;
    uint256 endTime;
}

struct FeeSchedule {
    bytes32[] receiver;
    uint16[] basisPoints;
}

struct FeeAllocation {
    bytes32 to; // The ID of the entity that receives the fee
    uint256 fee; // The amount of fees paid to the receiver
    uint256 basisPoints; // The basis points taken from the amount transacted
}

struct CalculatedFees {
    uint256 totalFees; // total amount of fees paid
    uint256 totalBP; // total basis points of fees paid
    FeeAllocation[] feeAllocations; // The list of entities that receive a portion of the fees.
}

struct StakingConfig {
    bytes32 tokenId;
    uint256 initDate;
    uint64 a; // Amplification factor
    uint64 r;
    uint64 divider;
    uint64 interval; // Amount of time per interval in seconds
}

struct StakingState {
    uint256 balance;
    uint256 boost;
    uint64 lastCollectedInterval;
}

struct RewardsBalances {
    bytes32[] currencies;
    uint256[] amounts;
    uint64 lastPaidInterval;
}

struct PermitSignature {
    uint256 deadline;
    uint8 v;
    bytes32 r;
    bytes32 s;
}

struct OnboardingApproval {
    bytes32 entityId;
    bytes32 roleId;
    bytes signature;
}
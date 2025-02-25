// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {BoostType, Equipment} from "./contracts_globals_misc.sol";

struct GuaranteedReward {
  uint16 itemTokenId;
  uint16 rate; // num per hour (base 10, 1 decimal) for actions and num per duration for passive actions
}

struct RandomReward {
  uint16 itemTokenId;
  uint16 chance; // out of 65535
  uint8 amount; // out of 255
}

struct PendingRandomReward {
  uint16 actionId;
  uint40 startTime;
  uint24 xpElapsedTime;
  uint16 boostItemTokenId;
  uint24 elapsedTime;
  uint40 boostStartTime; // When the boost was started
  uint24 sentinelElapsedTime;
  // Full equipment at the time this was generated
  uint8 fullAttireBonusRewardsPercent;
  uint64 queueId; // TODO: Could reduce this if more stuff is needed
}

struct ActionRewards {
  uint16 guaranteedRewardTokenId1;
  uint16 guaranteedRewardRate1; // Num per hour base 10 (1 decimal) for actions (Max 6553.5 per hour), num per duration for passive actions
  uint16 guaranteedRewardTokenId2;
  uint16 guaranteedRewardRate2;
  uint16 guaranteedRewardTokenId3;
  uint16 guaranteedRewardRate3;
  // Random chance rewards
  uint16 randomRewardTokenId1;
  uint16 randomRewardChance1; // out of 65535
  uint8 randomRewardAmount1; // out of 255
  uint16 randomRewardTokenId2;
  uint16 randomRewardChance2;
  uint8 randomRewardAmount2;
  uint16 randomRewardTokenId3;
  uint16 randomRewardChance3;
  uint8 randomRewardAmount3;
  uint16 randomRewardTokenId4;
  uint16 randomRewardChance4;
  uint8 randomRewardAmount4;
  // No more room in this storage slot!
}

struct XPThresholdReward {
  uint32 xpThreshold;
  Equipment[] rewards;
}

enum InstantVRFActionType {
  NONE,
  GENERIC,
  FORGING,
  EGG
}

struct InstantVRFActionInput {
  uint16 actionId;
  uint16[] inputTokenIds;
  uint24[] inputAmounts;
  bytes data;
  InstantVRFActionType actionType;
  bool isFullModeOnly;
  bool isAvailable;
  uint16 questPrerequisiteId;
}

struct InstantVRFRandomReward {
  uint16 itemTokenId;
  uint16 chance; // out of 65535
  uint16 amount; // out of 65535
}

uint256 constant MAX_GUARANTEED_REWARDS_PER_ACTION = 3;
uint256 constant MAX_RANDOM_REWARDS_PER_ACTION = 4;
uint256 constant MAX_REWARDS_PER_ACTION = MAX_GUARANTEED_REWARDS_PER_ACTION + MAX_RANDOM_REWARDS_PER_ACTION;
uint256 constant MAX_CONSUMED_PER_ACTION = 3;
uint256 constant MAX_QUEST_REWARDS = 2;

uint256 constant TIER_1_DAILY_REWARD_START_XP = 0;
uint256 constant TIER_2_DAILY_REWARD_START_XP = 7_650;
uint256 constant TIER_3_DAILY_REWARD_START_XP = 33_913;
uint256 constant TIER_4_DAILY_REWARD_START_XP = 195_864;
uint256 constant TIER_5_DAILY_REWARD_START_XP = 784_726;
uint256 constant TIER_6_DAILY_REWARD_START_XP = 2_219_451;

// 4 bytes for each threshold, starts at 500 xp in decimal
bytes constant XP_THRESHOLD_REWARDS = hex"00000000000001F4000003E8000009C40000138800002710000075300000C350000186A00001D4C0000493E0000557300007A120000927C0000B71B0000DBBA0000F424000124F800016E360001B7740001E8480002625A0002932E0002DC6C0003567E0003D0900004C4B40005B8D80006ACFC0007A1200008954400098968000A7D8C000B71B0000C65D4000D59F8000E4E1C0";
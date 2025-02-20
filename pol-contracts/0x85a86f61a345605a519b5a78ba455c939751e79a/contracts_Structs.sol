// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import "./uniswap_v2-periphery_contracts_interfaces_IUniswapV2Router02.sol";
import "./contracts_Interfaces.sol";

enum InvestmentType {
    subscription,
    investment
}

enum BusinessType {
    self,
    direct,
    team
}

enum RewardType {
    referral,
    roiReferral,
    investmentROI,
    club,
    performance
}

enum ContractType {
    registration,
    invest,
    rewards,
    uniswapV2Router
}

struct StructUserAccount {
    address user;
    address referrer;
    address[] referees;
    StructTeam[] teams;
    mapping(InvestmentType => StructUserInvestments[]) investments;
    mapping(InvestmentType => StructBusiness) business;
    mapping(InvestmentType => mapping(RewardType => uint256)) pendingRewards;
    mapping(InvestmentType => mapping(RewardType => uint256)) rewardsClaimed;
    mapping(InvestmentType => mapping(address => uint256)) rewardClaimedInTokens;
    mapping(InvestmentType => mapping(address => uint256)) investedWithTokens;
    mapping(InvestmentType => mapping(RewardType => uint256)) rewardId;
    mapping(InvestmentType => uint256) subscriptionStartTime;
    mapping(InvestmentType => uint256) subscriptionDuration;
}

struct StructUserAccountReturn {
    address user;
    address referrer;
    address[] referees;
    StructTeam[] teams;
    StructBusinessReturn business;
    uint256[] pendingRewards;
    uint256[] rewardsClaimed;
    StructTokenWithValue[] rewardClaimedInTokens;
    StructTokenWithValue[] investedWithTokens;
    StructUserInvestments[] investments;
    uint256[] rewardIds;
    uint256 subscriptionStartTime;
    uint256 subscriptionDuration;
}

struct StructRewardWithValue {
    RewardType rewardType;
    uint256 value;
}

struct StructDefaults {
    address[] adminsList;
    mapping(address => StructAdmin) admin;
    mapping(ContractType => address) contracts;
    mapping(ContractType => address) implementations;
    mapping(InvestmentType => StructReferralRates[]) referralRates;
    mapping(InvestmentType => uint256) calLevelsLimit;
    StructSupportedToken nativeToken;
    StructSupportedToken projectToken;
    StructSupportedToken stableToken;
    StructSupportedToken[] supportedTokensArray;
    mapping(address => StructSupportedToken) supportedToken;
    mapping(InvestmentType => mapping(uint256 => StructInvestmentPlan)) investmentPlan;
    mapping(InvestmentType => mapping(RewardType => mapping(uint256 => StructRewardObjectDefaults))) rewardObjectDefaults;
    uint256 initialUsdValueOfProjectToken;
    mapping(InvestmentType => StructPerWithDivision) createLiquidityPer;
    mapping(InvestmentType => StructPerWithDivision) swapPer;
    mapping(InvestmentType => StructFeesWithTimeline[]) preUnStakeFees;
    mapping(InvestmentType => StructFeesWithTimeline[]) claimFees;
    StructAdmin provider;
    StructAdmin beneficiary;
    StructPerWithDivision inactiveUserFees;
}

struct StructDefaultsReturn {
    address[] adminsList;
    address[] implementations;
    address[] contracts;
    StructReferralRates[] referralRates;
    uint256 calLevelsLimit;
    StructSupportedToken nativeToken;
    StructSupportedToken projectToken;
    StructSupportedToken stableToken;
    StructSupportedToken[] supportedTokensArray;
    StructInvestmentPlan[] investmentPlans;
    uint256 initialUsdValueOfProjectToken;
    StructPerWithDivision createLiquidityPer;
    StructPerWithDivision swapPer;
    StructFeesWithTimeline[] preUnStakeFees;
    StructFeesWithTimeline[] claimFees;
    StructAdminReturn provider;
    StructAdminReturn beneficiary;
    StructPerWithDivision inactiveUserFees;
}

struct StructAnalytics {
    mapping(address => StructUserAccount) userAccount;
    address[] users;
    StructUserInvestments[] investmentsArray;
    mapping(InvestmentType => uint256) totalBusiness;
    mapping(InvestmentType => mapping(RewardType => uint256)) rewardsDistributed;
    mapping(InvestmentType => mapping(address => uint256)) tokensCollected;
    mapping(InvestmentType => mapping(address => uint256)) rewardDistributedInTokens;
    mapping(InvestmentType => mapping(RewardType => mapping(uint256 => StructRewardDistributionObject))) rewardObject;
    mapping(InvestmentType => StructCalRewardWithBusiness) calReward;
    address defaultsContract;
}

struct StructAnalyticsReturn {
    address[] users;
    StructUserInvestments[] investmentsArray;
    uint256 totalBusiness;
    uint256[] rewardsDistributed;
    StructTokenWithValue[] tokensCollected;
    StructTokenWithValue[] rewardDistributedInTokens;
    StructRewardDistributionObjectReturn[] rewardObject;
    StructCalRewardWithBusiness calReward;
    address defaultsContract;
}

struct StructRewardObjectDefaults {
    uint256 id;
    string name;
    uint256 userInitialTimeCondition;
    uint256 refereeCondition;
    uint256 refereeRewardIdCondition;
    uint256 powerBusinessCount;
    uint256 powerBusinessValue;
    uint256 weakerBusinessCount;
    uint256 weakerBusinessValue;
    uint256 maxUsersLimit;
    uint256 rewardToDistribute;
    StructPerWithDivision perToDistribute;
    InvestmentType investmentType;
    RewardType rewardType;
}

struct StructRewardDistributionObject {
    StructRewardObjectDefaults rewardDefaults;
    uint256 rewardDistributed;
    uint256 calReward;
    address[] achievers;
    mapping(address => uint256) userIndex;
    mapping(address => uint256) rewardClaimedByUser;
    mapping(address => uint256) userCalReward;
}

struct StructRewardDistributionObjectReturn {
    StructRewardObjectDefaults rewardDefaults;
    uint256 rewardDistributed;
    uint256 calReward;
    address[] achievers;
}

struct StructCalRewardWithBusiness {
    uint256 reward;
    uint256 business;
}

struct StructTeam {
    address member;
    uint256 level;
}

struct StructBusiness {
    mapping(BusinessType => uint256) totalBusinessByType;
    uint256 teamBusinessTypeCount;
    uint256 calBusiness;
}

struct StructBusinessReturn {
    uint256 selfBusiness;
    uint256 directBusiness;
    uint256 teamBusiness;
    uint256 teamBusinessTypeCount;
    uint256 calBusiness;
}

struct StructInvestmentPlan {
    uint256 id;
    string name;
    bool isActive;
    InvestmentType investmentType;
    bool requireSubscription;
    uint256 fixedValueInUSD;
    uint256 minContribution;
    bool isPayReferral;
    bool isPayRefferalOnROI;
    uint256 duration;
    StructPerWithDivision perApy;
    StructPerWithDivision maxLimitMultiplier;
}

struct StructUserInvestments {
    uint256 id;
    address user;
    StructInvestmentPlan investmentPlan;
    StructSupportedToken tokenAccount;
    uint256 tokenValueInWei;
    uint256 tokenPrice;
    uint256 valueInUSD;
    uint256 timestamp;
    uint256 rewardClaimed;
    uint256 calRewardClaimed;
    uint256 pendingReward;
}

struct StructBusinessWithDetails {
    InvestmentType investmentType;
    uint256 timeStamp;
    address user;
    address updatedTo;
    uint256 valueInUSD;
    uint256 valueInWei;
    address tokenAddress;
    uint256 level;
}

struct StructTransaction {
    address user;
    address token;
    uint256 tokenValue;
    uint256 valueInUSD;
    uint256 level;
    uint256 timeStamp;
}

struct StructTokenWithValue {
    address tokenAddress;
    uint256 tokenValue;
}

struct StructPerWithDivision {
    uint256 per;
    uint256 division;
}

struct StructSupportedToken {
    bool isActive;
    bool isNative;
    address contractAddress;
    address chainLinkAggregatorV3Address;
    string name;
    string symbol;
    uint8 decimals;
}

struct StructReferralRates {
    StructPerWithDivision referralRate;
    uint256 levelCondition;
}

struct StructAdmin {
    address adminAddress;
    bool status;
    mapping(InvestmentType => StructPerWithDivision) transferPer;
    mapping(address => uint256) transfersInTokens;
    mapping(address => uint256) pendingTransfersInTokens;
    uint256 transferedInUSD;
}

struct StructAdminTransferPer {
    InvestmentType investmentType;
    StructPerWithDivision transferPer;
}

struct StructAdminReturn {
    address adminAddress;
    bool status;
    StructAdminTransferPer[] transferPer;
    StructTokenWithValue[] transfersInTokens;
    StructTokenWithValue[] pendingTransfersInTokens;
    uint256 transferedInUSD;
}

struct StructFeesWithTimeline {
    StructPerWithDivision feesPer;
    uint256 durationBefore;
}
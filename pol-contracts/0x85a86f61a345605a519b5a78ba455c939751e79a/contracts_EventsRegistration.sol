//SPDX-License-Identifier: MIT

pragma solidity ^0.8.26;

import "./contracts_Structs.sol";

event Invested(StructUserInvestments);
event InvestmentRewardClaimed(address user, address token, uint256 value);
event InvestmentRewardDistributed(address token, uint256 valueInWei);
event CalRewardUpdated(uint256 calValue, address user);
event InvestmentRemoved(address user, uint256 investmentId);

event InvestmentDisabled(uint256 id);

event PreUnStakeFeedDeducted(uint256 id, uint256 fees);

event InvestmentInterestDistributed(uint256 investmentId, uint256 valueInUSD);

event ReferrerAdded(address referrer, address user);

event TeamAdded(address parent, address user);

event BusinessUpdated(
    address referrer,
    BusinessType businessType,
    uint256 valueInUSD,
    uint256 level
);

event UserPendingRewardUpdated(uint256 value, RewardType);

event ReferralPaid(
    address referrer,
    address user,
    uint256 level,
    address token,
    uint256 valueInTokens,
    uint256 valueInUSD,
    InvestmentType rewardType
);

event ReferralNotPaid(
    address referrer,
    address user,
    uint256 level,
    string reason,
    InvestmentType rewardType
);
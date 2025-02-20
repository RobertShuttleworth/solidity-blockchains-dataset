// Compatible with OpenZeppelin Contracts ^5.0.0
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import "./contracts_Structs.sol";

event CommonEvent(string reason);
error CommonError(string cause);
event VariablesContractUpdated(address);
event AdminStatusChanged(address, bool);

event BeneficiaryRewardUpdted(
    address beneficiary,
    address tokenAddress,
    uint256 valueInWei
);

event BeneficiaryRewardPaid(
    address beneficiary,
    address tokenAddress,
    uint256 valueInWei
);

event ProviderRewardUpdated(
    address provider,
    address tokenAddress,
    uint256 valueInWei
);

event ProviderRewardPaid(
    address provider,
    address tokenAddress,
    uint256 valueInWei
);

event InactiveUserFeesDeducted(
    address user,
    string reason,
    uint256 feesInWei,
    InvestmentType,
    RewardType
);

event DefaultsContractUpdated(address defaultsContractAddress);
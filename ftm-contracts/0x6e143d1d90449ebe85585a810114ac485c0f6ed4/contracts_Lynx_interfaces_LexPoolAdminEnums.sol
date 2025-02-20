// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.24;

interface LexPoolAdminEnums {
  enum LexPoolAddressesEnum {
    none,
    poolAccountant,
    pnlRole
  }

  enum LexPoolNumbersEnum {
    none,
    maxExtraWithdrawalAmountF,
    epochsDelayDeposit,
    epochsDelayRedeem,
    epochDuration,
    minDepositAmount
  }
}
// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.24;

interface PoolAccountantV1AdminEnums {
  enum PoolAccountantAddressesEnum {
    none,
    irm,
    frm,
    incentivizer
  }

  enum PoolAccountantV1NumbersEnum {
    none,
    minOpenFee,
    lexPartF,
    maxGainF,
    liquidationThresholdF,
    liquidationFeeF,
    fundingRateMax,
    interestShareFactor,
    borrowRateMax,
    maxTotalBorrows,
    maxVirtualUtilization,
    fundingShareFactor
  }
}
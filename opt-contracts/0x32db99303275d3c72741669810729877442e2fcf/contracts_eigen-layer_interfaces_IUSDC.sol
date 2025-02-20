// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

interface IUSDC {
  struct Config {
    uint256 blocksPerDay;
    uint256 depositLimit;
    uint256 maxDelegations;
    uint256 minDepositAmount;
    uint256 minWithdrawAmount;
    uint256 poolSize;
    uint256 validatorSize;
    uint256 withdrawalPoolLimit;
    uint256 withdrawalValidatorLimit;
    uint256 withdrawDelay;
    uint256 withdrawBeaconDelay;
    Feature feature;
  }

  struct Delegation {
    address pool;
    uint256 percentage;
  }

  struct Feature {
    bool AddPool;
    bool Deposit;
    bool WithdrawPool;
    bool WithdrawBeacon;
  }

  struct Fee {
    uint256 value;
    mapping(FeeRole => uint256) allocations;
  }

  enum DepositType {
    Donation,
    Pool
  }

  enum WithdrawType {
    Pool,
    Validator
  }

  enum FeeType {
    Entry,
    Rewards,
    Pool,
    Validator
  }

  enum FeeRole {
    Airdrop,
    Operator,
    StakeTogether,
    Sender
  }
}
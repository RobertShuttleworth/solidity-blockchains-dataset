// SPDX-License-Identifier: MIT
pragma solidity 0.8.18;

interface IStakingLocker {
  error StakingLocker_Unauthorized();
  error StakingLocker_InvalidStatus();
  error StakingLocker_CooldownNotOver();

  enum UnstakingStatus {
    Cooldown,
    Claimed,
    Cancelled
  }

  event LogLock(address indexed caller, address token, uint256 amount, uint256 lockEndTimestamp);
  event LogCancelLock(
    uint256 indexed positionIndex,
    address indexed account,
    address token,
    uint256 amount,
    uint256 lockEndTimestamp
  );
  event LogClaimLock(
    uint256 indexed positionIndex,
    address indexed account,
    address token,
    uint256 amount,
    uint256 lockEndTimestamp
  );
  event LogSetUnstakingCooldownPeriod(address stakingToken, uint256 cooldownPeriod);

  struct UnstakingPosition {
    address token;
    uint256 amount;
    uint256 lockEndTimestamp;
    UnstakingStatus status;
  }

  function unstakingCooldownPeriod(address stakingToken) external returns (uint256 cooldownPeriod);

  function setUnstakingCooldownPeriod(address _stakingToken, uint256 _cooldownPeriod) external;

  function lock(address account, address stakingToken, uint256 amount) external;

  function cancelLocks(uint256[] memory positionIndexes) external;

  function claimLocks(uint256[] memory positionIndexes) external;

  function unstakingPositions(
    address user,
    uint256 index
  )
    external
    returns (address token, uint256 amount, uint256 lockEndTimestamp, UnstakingStatus status);
}
//SPDX-License-Identifier: Unlicense
pragma solidity 0.8.18;

interface IUniV3LiquidityMining {
  function upKeep(uint64 maxIndex, bool rolloverRewards) external;

  function incentives(
    uint256 activeIncentiveId
  )
    external
    view
    returns (
      uint256 totalRewardUnclaimed,
      uint160 totalSecondsClaimedX128,
      uint96 numberOfStakes,
      uint64 startTime,
      uint64 endTime
    );

  function activeIncentiveId() external view returns (uint256);

  function keeper() external view returns (address);
}
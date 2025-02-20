// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.19;

interface IAbraStaking {
    function epoch() external view returns (uint256);
    function minStakeDuration() external view returns (uint256);
    function maxStakeDuration() external view returns (uint256);

    function stake(uint256 amount, uint256 duration, address to) external returns (uint64 lockupId);

    function lockupsLength(address staker) external view returns (uint);

    function lockups(
        address taker,
        uint lockupId
    ) external view returns (uint128 amount, uint128 end, uint256 points);

    function abra() external view returns (address);
}
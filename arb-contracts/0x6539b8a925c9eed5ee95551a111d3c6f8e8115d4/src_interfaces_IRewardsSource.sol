// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.19;

interface IRewardsSource {

    function previewRewards() external view returns(uint);
    function collectRewards() external;

}
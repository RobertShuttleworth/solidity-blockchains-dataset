// SPDX-License-Identifier: MIT

pragma solidity 0.8.26;

interface IClaimable {
    function hasClaimed(bytes32 claimId_) external view returns (bool);
}
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

contract EarthToSaturnDistance {
    uint256 public constant distanceInKm = 1_200_000_000; // Distance in kilometers

    function getDistance() public pure returns (uint256) {
        return distanceInKm;
    }
}
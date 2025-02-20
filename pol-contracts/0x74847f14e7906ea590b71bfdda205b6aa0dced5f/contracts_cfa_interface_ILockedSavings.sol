// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

interface ILockedSavings {
    struct Attributes {
        uint256 timeCreated;
        uint256 multiplier;
        uint256 marker;
        uint256 cfaLife;
        uint256 principal;
        uint256 discountGiven;
    }

    struct Metadata {
        string name;
        string description;
        string image;
    }

    struct System {
        uint256 minMarker;
        uint256 maxMarker;
        uint256 idCounter;
        uint256 totalActiveCfa;
    }
}
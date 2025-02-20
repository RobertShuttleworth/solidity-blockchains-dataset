// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.26;

uint32 constant DAY  = (1 days);
uint32 constant WEEK = (1 days);

function currentEpoch() view returns (uint32) {
    uint256 lastThursDay = (block.timestamp / WEEK) * WEEK;
    if ((block.timestamp - lastThursDay) < 9 hours) {
        return uint32(lastThursDay - WEEK) + 9 hours;
    }
    return uint32(lastThursDay + 9 hours);
}

function previousEpoch() view returns (uint32) {
    return currentEpoch() - WEEK;
}

function nextEpoch() view returns (uint32) {
    return currentEpoch() + WEEK;
}
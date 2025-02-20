// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity ^0.7.0;
pragma abicoder v2;

interface IV3PairPool {
    struct Slot0 {
        // the current price
        uint160 sqrtPriceX96;
        // the current tick
        int24 tick;
        // the most-recently updated index of the observations array
        uint16 observationIndex;
        // the current maximum number of observations that are being stored
        uint16 observationCardinality;
        // the next maximum number of observations to store, triggered in observations.write
        uint16 observationCardinalityNext;
        // the current protocol fee for token0 and token1,
        // 2 uint32 values store in a uint32 variable (fee/PROTOCOL_FEE_DENOMINATOR)
        uint32 feeProtocol;
        // whether the pool is locked
        bool unlocked;
    }

    function slot0() external view returns (Slot0 memory);

    function token0() external view returns (address);

    function token1() external view returns (address);
}
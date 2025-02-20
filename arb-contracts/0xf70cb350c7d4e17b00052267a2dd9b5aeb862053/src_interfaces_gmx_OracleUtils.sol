// SPDX-License-Identifier: BUSL-1.1

pragma solidity ^0.8.0;

// @title OracleUtils
// @dev Library for oracle functions
library OracleUtils {
    struct SetPricesParams {
        address[] tokens;
        address[] providers;
        bytes[] data;
    }

    struct ValidatedPrice {
        address token;
        uint256 min;
        uint256 max;
        uint256 timestamp;
        address provider;
    }
}
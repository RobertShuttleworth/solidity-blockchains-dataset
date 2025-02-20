// SPDX-License-Identifier: UNLICENSED

pragma solidity 0.8.24;

interface IGBCRouter {
    struct Fees {
        /// @notice The numerator for calculating the fee.
        uint16 feeNumerator;
        /// @notice The denominator for calculating the fee.
        uint16 feeDenominator;
    }

    function getGlvRouter() external view returns (address);

    function getExchangeRouter() external view returns (address);

    function getWithdrawalFees() external view returns (Fees memory);

    function getFeeReceiver() external view returns (address);
}
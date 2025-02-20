// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

/// @title SafeMath
/// @notice A library for performing overflow-checked arithmetic operations and finding min/max values.
library SafeMath {
    /// @dev Returns the larger of two numbers.
    /// @param a The first number.
    /// @param b The second number.
    /// @return The larger of `a` and `b`.
    function max(int256 a, int256 b) internal pure returns (int256) {
        return a >= b ? a : b;
    }

    /// @dev Returns the smaller of two numbers.
    /// @param a The first number.
    /// @param b The second number.
    /// @return The smaller of `a` and `b`.
    function min(int256 a, int256 b) internal pure returns (int256) {
        return a < b ? a : b;
    }
}
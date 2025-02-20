// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

// solhint-disable func-name-mixedcase

interface IATokenV3 {
    /// @notice Returns the pool related to this token
    function POOL() external returns (address);

    /// @notice Returns the underlying token this one wraps
    function UNDERLYING_ASSET_ADDRESS() external returns (address);

    /// @notice Returns the balance of the provided wallet
    function balanceOf(
        address
    ) external returns (uint256);
}
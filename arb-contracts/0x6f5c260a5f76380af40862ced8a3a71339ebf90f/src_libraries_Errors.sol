// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.10;

library Errors {
    /// @notice Error when an invalid address is provided
    error InvalidAddress();

    /// @notice Error when caller is not authorized to action
    error NotAuthorized();
}
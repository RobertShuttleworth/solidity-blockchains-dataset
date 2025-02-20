// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.24;

/// @title SubVault Errors Interface
/// @notice Custom errors for subvault operations
/// @dev All possible errors that can be thrown by SubVault
interface ISubVaultErrors {
    /// @notice Thrown when caller is not authorized
    /// @param caller Address of unauthorized caller
    error UnauthorizedCaller(address caller);

    /// @notice Thrown when asset operation is unsupported
    /// @param asset Address of unsupported asset
    error UnsupportedAsset(address asset);

    /// @notice Thrown when asset is already configured
    /// @param asset Address of already supported asset
    error AssetAlreadySupported(address asset);

    /// @notice Thrown when address is invalid (usually zero)
    /// @param addr The invalid address
    error InvalidAddress(address addr);

    /// @notice Thrown when amount is invalid (usually zero)
    error InvalidAmount();

    /// @notice Thrown when deposit operation fails
    /// @param reason Description of failure
    error DepositFailed(string reason);

    /// @notice Thrown when withdrawal operation fails
    /// @param reason Description of failure
    error WithdrawFailed(string reason);

    /// @notice Thrown when emergency delay period hasn't passed
    error EmergencyDelayNotPassed();

    /// @notice Thrown when emergency mode is active
    /// @param timestamp Time when emergency mode was enabled
    error EmergencyModeEnabled(uint256 timestamp);

    /// @notice Thrown when emergency mode is not active
    error EmergencyModeNotEnabled();

    /// @notice Thrown when balance is insufficient
    /// @param requested Amount requested
    /// @param available Amount available
    error InsufficientBalance(uint256 requested, uint256 available);

    /// @notice Thrown when approval operation fails
    /// @param asset Asset for which approval failed
    /// @param spender Address that was to be approved
    error ApprovalFailed(address asset, address spender);

    /// @notice Thrown when attempting to remove primary asset
    error CannotRemovePrimaryAsset();

    /// @notice Thrown when primary asset operation fails
    /// @param reason Description of failure
    error PrimaryAssetOperationFailed(string reason);

    /// @notice Thrown when secondary asset operation fails
    /// @param reason Description of failure
    error SecondaryAssetOperationFailed(string reason);

    /// @notice Thrown when usual not initialized
    error NotInitialized();
}
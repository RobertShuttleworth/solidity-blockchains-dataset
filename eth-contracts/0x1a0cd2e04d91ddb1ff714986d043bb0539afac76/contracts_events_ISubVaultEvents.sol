// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.24;

/// @title SubVault Events Interface
/// @notice Events emitted by subvault operations
/// @dev All events that can be emitted by SubVault
interface ISubVaultEvents {
    /// @notice Emitted when router address is set
    /// @param router Address of the newly set router contract
    /// @dev Router can only be set once and is critical for deposit operations
    event RouterSet(address indexed router);

    event AssetOracleSet(address indexed asset, address indexed oracle);
    /// @notice Emitted when an asset is added to supported assets
    /// @param asset Address of added asset
    /// @param reason Reason for adding
    event AssetAdded(address indexed asset, string reason);

    /// @notice Emitted when an asset is removed from supported assets
    /// @param asset Address of removed asset
    /// @param reason Reason for removal
    event AssetRemoved(address indexed asset, string reason);

    /// @notice Emitted when a deposit is processed
    /// @param user User who deposited
    /// @param asset Asset deposited
    /// @param amount Amount deposited
    /// @param shares Shares minted
    event DepositProcessed(
        address indexed user,
        address indexed asset,
        uint256 amount,
        uint256 shares
    );

    /// @notice Emitted when a withdrawal is processed
    /// @param user User who withdrew
    /// @param asset Asset withdrawn
    /// @param amount Amount withdrawn
    event WithdrawProcessed(address indexed user, address indexed asset, uint256 amount);

    /// @notice Emitted when emergency withdrawal is executed
    /// @param asset Asset withdrawn
    /// @param to Recipient address
    /// @param amount Amount withdrawn
    /// @param reason Reason for withdrawal
    event EmergencyWithdrawalExecuted(
        address indexed asset,
        address indexed to,
        uint256 amount,
        string reason
    );

    /// @notice Emitted when emergency mode status changes
    /// @param timestamp Time of change
    /// @param enabled New status
    event EmergencyModeSet(uint256 timestamp, bool enabled);

    /// @notice Emitted when admin role changes
    /// @param oldAdmin Previous admin address
    /// @param newAdmin New admin address
    event AdminChanged(address indexed oldAdmin, address indexed newAdmin);

    /// @notice Emitted when approval is granted
    /// @param asset Asset approved
    /// @param spender Address approved to spend
    /// @param amount Amount approved
    event ApprovalGranted(address indexed asset, address indexed spender, uint256 amount);

    /// @notice Emitted when approval is revoked
    /// @param asset Asset for which approval was revoked
    /// @param spender Address whose approval was revoked
    event ApprovalRevoked(address indexed asset, address indexed spender);

    /// @notice Emitted when primary asset operation occurs
    /// @param user User involved in operation
    /// @param amount Amount involved
    /// @param isDeposit Whether operation was deposit
    event PrimaryAssetOperation(address indexed user, uint256 amount, bool isDeposit);

    /// @notice Emitted when secondary asset operation occurs
    /// @param asset Secondary asset involved
    /// @param user User involved in operation
    /// @param amount Amount involved
    /// @param isDeposit Whether operation was deposit
    event SecondaryAssetOperation(
        address indexed asset,
        address indexed user,
        uint256 amount,
        bool isDeposit
    );
}
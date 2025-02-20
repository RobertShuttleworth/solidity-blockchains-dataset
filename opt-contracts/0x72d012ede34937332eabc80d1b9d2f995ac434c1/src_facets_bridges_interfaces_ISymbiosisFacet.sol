// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

/// @title ISymbiosisFacet - SymbiosisFacet interface
interface ISymbiosisFacet {
    // =========================
    // events
    // =========================

    /// @notice Emits when a call fails
    event CallFailed(bytes errorMessage);

    // =========================
    // errors
    // =========================

    /// @notice Throws if `sender` tries to call a function with tokens that were not sent for it
    error SymbiosisFacet_NotSymbiosisMetaRouter();

    // =========================
    // getters
    // =========================

    /// @notice Gets portal address
    function portal() external view returns (address);

    // =========================
    // main function
    // =========================

    struct SymbiosisTransaction {
        uint256 stableBridgingFee;
        uint256 amount;
        address rtoken;
        address chain2address;
        address[] swapTokens;
        bytes secondSwapCalldata;
        address finalReceiveSide;
        bytes finalCalldata;
        uint256 finalOffset;
    }

    /// @notice Send Symbiosis Transaction
    function sendSymbiosis(SymbiosisTransaction calldata symbiosisTransaction) external;
}
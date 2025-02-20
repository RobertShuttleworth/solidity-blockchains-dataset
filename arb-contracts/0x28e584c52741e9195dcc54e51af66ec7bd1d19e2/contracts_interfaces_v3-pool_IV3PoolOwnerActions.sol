// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity >=0.5.0;

/// @title Permissioned pool actions
/// @notice Contains pool methods that may only be called by the factory owner
interface IV3PoolOwnerActions {
    /// @notice Set the denominator of the protocol's % share of the fees
    /// @param feeProtocol0 new protocol fee for amount0 of the pool
    /// @param feeProtocol1 new protocol fee for amount1 of the pool
    function setFeeProtocol(uint8 feeProtocol0, uint8 feeProtocol1) external;

    /// @notice Collect the protocol fee accrued to the pool
    /// @param recipient The address to which collected protocol fees should be sent
    /// @param amountRequested The maximum amount of token to send, can be 0 to collect fees in only token1
    /// @return amount The protocol fee collected in token
    function collectProtocol(
        address recipient,
        uint128 amountRequested
    ) external returns (uint128 amount);
}
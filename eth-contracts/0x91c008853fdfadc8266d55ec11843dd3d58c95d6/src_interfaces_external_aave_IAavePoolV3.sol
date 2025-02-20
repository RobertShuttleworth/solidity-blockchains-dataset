// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

interface IAavePoolV3 {
    /// @notice Withdraws an `amount` of underlying asset from the reserve, burning the equivalent aTokens owned E.g.
    /// User has 100 aUSDC, calls withdraw() and receives 100 USDC, burning the 100 aUSDC
    /// @param asset The address of the underlying asset to withdraw
    /// @param amount The underlying amount to be withdrawn - Send the value type(uint256).max in order to withdraw the
    /// whole aToken balance
    /// @param to Address that will receive the underlying, same as msg.sender if the user wants to receive it on his
    /// own wallet, or a different address if the beneficiary is a different wallet
    /// @return The final amount withdrawn
    function withdraw(address asset, uint256 amount, address to) external returns (uint256);

    /// @notice Returns the normalized income of the reserve
    /// @return The reserve's normalized income
    function getReserveNormalizedIncome(
        address asset
    ) external returns (uint256);
}
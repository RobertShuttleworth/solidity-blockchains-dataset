// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {DataTypes} from "./src_libraries_types_DataTypes.sol";

interface IVault {
    /**
     * @notice Supply assets to be used as collateral
     * @param asset The address of the asset to supply
     * @param amount The amount to supply
     * @param onBehalfOf The address who will receive the aTokens
     * @param referralCode Referral code for tracking
     */
    function supply(address asset, uint256 amount, address onBehalfOf, uint16 referralCode) external payable;

    /**
     * @notice Withdraw supplied assets
     * @param asset The address of the asset to withdraw
     * @param amount The amount to withdraw
     * @param to The address that will receive the withdrawn assets
     */
    function withdraw(address asset, uint256 amount, address to) external payable;

    /**
     * @notice Borrow an asset
     * @param asset The address of the asset to borrow
     * @param amount The amount to borrow
     * @param onBehalfOf The address who will receive the borrowed assets
     * @param referralCode Referral code for tracking
     */
    function borrow(address asset, uint256 amount, address onBehalfOf, uint256 interestRateMode, uint16 referralCode)
        external
        payable;

    /**
     * @notice Repay borrowed assets
     * @param asset The address of the asset to repay
     * @param amount The amount to repay
     * @param onBehalfOf The address of the borrowed position to repay
     */
    function repay(address asset, uint256 amount, uint256 interestRateMode, address onBehalfOf)
        external
        payable
        returns (uint256);

    /**
     * @notice Process withdrawal confirmation from hub chain
     * @param asset The asset being withdrawn
     * @param amount The amount being withdrawn
     * @param to Recipient address
     */
    function executeIntent(address asset, uint256 amount, address to) external;
}
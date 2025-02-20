// SPDX-License-Identifier: UNLICENSED

// Copyright (c) 2024 JonesDAO - All rights reserved
// Jones DAO: https://www.jonesdao.io/

// Check https://docs.jonesdao.io/jones-dao/other/bounty for details on our bounty program.

pragma solidity ^0.8.26;

import {IjGlvStrategy} from "./src_interfaces_glv_IjGlvStrategy.sol";
import {IjGlvRouter} from "./src_interfaces_glv_IjGlvRouter.sol";
import {IjGlvVault} from "./src_interfaces_glv_IjGlvVault.sol";

interface IjGlvViewer {
    function router() external view returns (IjGlvRouter);
    function strategy() external view returns (IjGlvStrategy);
    function vault() external view returns (IjGlvVault);

    function tokenPrice(address token) external view returns (uint256);

    function withdrawalData(uint256 shares)
        external
        view
        returns (uint256 extraAmount, uint256[] memory amounts, address[] memory glvs);

    function operationCheck() external view;

    function getGlvs() external view returns (address[] memory);

    function withdrawalInfo(bytes32 key) external view returns (IjGlvStrategy.WithdrawalInfo memory);

    /**
     * @dev most likely 18.
     */
    function jGlvDecimals() external view returns (uint8);

    /**
     * @dev Get total supply.
     */
    function jGlvSupply() external view returns (uint256);

    /**
     * @dev Get account balance.
     */
    function jGlvBalanceOf(address account) external view returns (uint256);

    /**
     * @dev Total Value in USD
     */
    function jGlvTotalValue() external view returns (uint256);

    /**
     * @dev Total Assets in USDC
     */
    function jGlvTotalAssets() external view returns (uint256);

    /**
     * @dev See {IERC4626-previewDeposit}.
     */
    function previewDeposit(uint256 assets) external view returns (uint256);

    /**
     * @dev See {IERC4626-previewRedeem}.
     */
    function previewRedeem(uint256 shares) external view returns (uint256);
}
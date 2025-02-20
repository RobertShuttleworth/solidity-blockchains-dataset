// SPDX-License-Identifier: UNLICENSED

// Copyright (c) 2024 JonesDAO - All rights reserved
// Jones DAO: https://www.jonesdao.io/

// Check https://docs.jonesdao.io/jones-dao/other/bounty for details on our bounty program.

pragma solidity ^0.8.26;

import {IjGlvStrategy} from "./src_interfaces_glv_IjGlvStrategy.sol";

interface IjGlvVault {
    function price(address token) external view returns (uint256);

    function strategy() external view returns (IjGlvStrategy);

    function mint(uint256 shares, address receiver) external;

    function burn(address owner, uint256 shares) external;

    /**
     * @dev most likely 18.
     */
    function decimals() external view returns (uint8);

    /**
     * @dev Get total supply.
     */
    function totalSupply() external view returns (uint256);

    /**
     * @dev Get account balance.
     */
    function balanceOf(address account) external view returns (uint256);

    /**
     * @dev Total Value in USD
     */
    function totalValue() external view returns (uint256);

    /**
     * @dev See {IERC4626-previewDeposit}.
     */
    function totalAssets() external view returns (uint256);

    /**
     * @dev See {IERC4626-previewDeposit}.
     */
    function previewDeposit(uint256 assets) external view returns (uint256);

    /**
     * @dev See {IERC4626-previewRedeem}.
     */
    function previewRedeem(uint256 shares) external view returns (uint256);

    error InvalidPrice();
    error StalePriceUpdate();
    error SequencerDown();
}
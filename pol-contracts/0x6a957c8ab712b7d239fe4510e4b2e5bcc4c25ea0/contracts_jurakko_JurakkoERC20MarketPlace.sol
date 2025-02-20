// SPDX-License-Identifier: MIT
// solhint-disable-next-line compiler-version
pragma solidity ^0.8.0;

import "./contracts_jurakko_Jurakko.sol";
import "./contracts_erc20-marketplace_MarketPlaceERC20.sol";

/**
 * @title JurakkoERC20MarketPlace
 * @dev JurakkoERC20MarketPlace is a marketplace for Jurakko ERC20 Token.
 */
contract JurakkoERC20MarketPlace is MarketPlaceERC20 {
    /**
     * @dev Constructor that gives msg.sender ownership on marketplace.
     */
    constructor(Jurakko jurakko, uint256 unitPrice) MarketPlaceERC20(jurakko, unitPrice) {
        
    }
}
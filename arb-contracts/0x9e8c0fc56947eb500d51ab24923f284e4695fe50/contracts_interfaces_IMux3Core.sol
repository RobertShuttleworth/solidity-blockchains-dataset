// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity 0.8.28;

import "./contracts_interfaces_IFacetTrade.sol";
import "./contracts_interfaces_IFacetManagement.sol";
import "./contracts_interfaces_IFacetReader.sol";

struct CollateralTokenInfo {
    bool isExist;
    uint8 decimals;
    bool isStable;
}
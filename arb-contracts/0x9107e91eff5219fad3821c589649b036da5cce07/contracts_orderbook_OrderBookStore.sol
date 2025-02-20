// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity 0.8.28;

import "./openzeppelin_contracts-upgradeable_access_AccessControlEnumerableUpgradeable.sol";
import "./openzeppelin_contracts-upgradeable_token_ERC20_IERC20Upgradeable.sol";
import "./openzeppelin_contracts-upgradeable_proxy_utils_Initializable.sol";
import "./openzeppelin_contracts-upgradeable_utils_structs_EnumerableSetUpgradeable.sol";

import "./contracts_interfaces_IOrderBook.sol";
import "./contracts_libraries_LibTypeCast.sol";

contract OrderBookStore is Initializable, AccessControlEnumerableUpgradeable {
    mapping(bytes32 => bytes32) internal _deprecated0;
    OrderBookStorage internal _storage; // should be the last variable before __gap
    bytes32[50] __gap;

    function __OrderBookStore_init() internal onlyInitializing {
        __AccessControlEnumerable_init();
    }
}
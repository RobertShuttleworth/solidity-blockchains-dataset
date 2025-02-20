// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity 0.8.28;

import "./openzeppelin_contracts-upgradeable_utils_structs_EnumerableSetUpgradeable.sol";
import "./openzeppelin_contracts-upgradeable_token_ERC20_extensions_IERC20MetadataUpgradeable.sol";

import "./contracts_interfaces_IMux3Core.sol";
import "./contracts_interfaces_ICollateralPool.sol";
import "./contracts_pool_CollateralPoolToken.sol";

contract CollateralPoolStore is CollateralPoolToken {
    address internal immutable _core;
    address internal immutable _orderBook;
    address internal immutable _weth;
    address internal immutable _eventEmitter;

    mapping(bytes32 => bytes32) internal _configTable;
    address internal _unused1; // was _core
    address internal _collateralToken;
    uint8 internal _unused2; // was _collateralDecimals
    uint256 internal _unused3; // was _liquidityBalance
    EnumerableSetUpgradeable.Bytes32Set internal _marketIds;
    mapping(bytes32 => MarketState) internal _marketStates; // marketId => Market
    mapping(address => uint256) internal _liquidityBalances; // token => balance(1e18)

    bytes32[49] private _gaps;

    function __CollateralPoolStore_init(address collateralToken) internal onlyInitializing {
        _collateralToken = collateralToken;
    }
}
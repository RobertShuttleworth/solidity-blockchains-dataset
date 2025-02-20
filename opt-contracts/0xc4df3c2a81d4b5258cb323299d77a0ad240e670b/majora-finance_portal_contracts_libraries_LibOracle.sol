// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

/******************************************************************************\
* Author: Nick Mudge <nick@perfectabstractions.com> (https://twitter.com/mudgen)
* EIP-2535 Diamonds: https://eips.ethereum.org/EIPS/eip-2535
/******************************************************************************/
import { IDiamondCut } from "./majora-finance_portal_contracts_interfaces_IDiamondCut.sol";
import "./openzeppelin_contracts_token_ERC20_IERC20.sol";
import "./openzeppelin_contracts_token_ERC20_utils_SafeERC20.sol";
import "./chainlink_contracts_src_v0.8_interfaces_AggregatorInterface.sol";
// Remember to add the loupe functions from DiamondLoupeFacet to the diamond.
// The loupe functions are required by the EIP2535 Diamonds standard

enum MajoraOracleAdaptersType {
    MAJORA_ORACLE,
    CHAINLINK,
    BALANCER_V2
}

library LibOracle {
    using SafeERC20 for IERC20;

    error OracleNotEnabled(address asset);

    bytes32 constant ORACLE_STORAGE_POSITION = keccak256("oracle.portal.majora.finance");

    struct OracleEntry {
        bool enabled;
        uint8 decimals;
        uint256 price;

        MajoraOracleAdaptersType adapterType;
        address adapter;
    }

    struct OracleStorage {
        mapping(address => OracleEntry) entries;
        mapping(address => bool) isUpdater;
    }

    function oracleStorage() internal pure returns (OracleStorage storage ds) {
        bytes32 position = ORACLE_STORAGE_POSITION;
        assembly {
            ds.slot := position
        }
    }

    function configureOracle(
        bool _enabled,
        address _asset,
        uint8 _assetDecimals,
        MajoraOracleAdaptersType _adapterType,
        address _adapter
    ) internal {
        OracleEntry storage oracle = oracleStorage().entries[_asset];
        oracle.enabled = _enabled;
        oracle.decimals = _assetDecimals;
        oracle.adapterType = _adapterType;
        oracle.adapter = _adapter;
    }

    function getOracleConfiguration(address _asset) internal view returns (OracleEntry memory) {
        return oracleStorage().entries[_asset];
    }

    function getAssetPrice(
        address _asset
    ) internal view returns (uint256 price) {

        OracleEntry storage oracle = oracleStorage().entries[_asset];
        if(!oracle.enabled) revert OracleNotEnabled(_asset);

        if(oracle.adapterType == MajoraOracleAdaptersType.CHAINLINK) {
            price = uint256(AggregatorInterface(oracle.adapter).latestAnswer());
        }

        if(oracle.adapterType == MajoraOracleAdaptersType.MAJORA_ORACLE) {
            price = oracle.price;
        }
    }

    function isUpdater(address _addr) internal view returns (bool) {
        return oracleStorage().isUpdater[_addr];
    }

    function setUpdater(bool _enabled, address _addr) internal returns (bool) {
        return oracleStorage().isUpdater[_addr] = _enabled;
    }

    function getRate(address _from, address _to, uint256 _amount) internal view returns (uint256) {

        OracleEntry storage from = oracleStorage().entries[_from];
        OracleEntry storage to = oracleStorage().entries[_to];

        if(!from.enabled) revert OracleNotEnabled(_from);
        if(!to.enabled) revert OracleNotEnabled(_to);

        uint256 fromBase = (_amount * getAssetPrice(_from)) /
            10 ** from.decimals;

        return fromBase * (10 ** to.decimals) / getAssetPrice(_to);
    }

    function setMajoraOraclePrice(
        address _from, 
        uint256 _price
    ) internal {
        OracleStorage storage store = oracleStorage();
        store.entries[_from].price = _price;
    }

    function priceIsEnabled(
        address _asset
    ) internal view returns (bool) {
        OracleStorage storage store = oracleStorage();
        return store.entries[_asset].enabled;
    }
}
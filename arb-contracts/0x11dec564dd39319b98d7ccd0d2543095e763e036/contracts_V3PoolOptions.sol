// SPDX-License-Identifier: None
pragma solidity ^0.8.18;

import {EnumerableSet} from "./openzeppelin_contracts_utils_structs_EnumerableSet.sol";

import {TickMath} from "./contracts_libraries_TickMath.sol";
import {FullMath} from "./contracts_libraries_FullMath.sol";
import {V3PoolUtils} from "./contracts_libraries_combo-pools_V3PoolUtils.sol";

import {SafeERC20} from "./openzeppelin_contracts_token_ERC20_utils_SafeERC20.sol";
import {ERC20} from "./openzeppelin_contracts_token_ERC20_ERC20.sol";

import {VanillaOptionPool} from "./contracts_libraries_combo-pools_VanillaOptionPool.sol";
import {OptionPoolBalance} from "./contracts_libraries_combo-pools_OptionPoolBalance.sol";
import {AddressApprovalUtils} from "./contracts_libraries_combo-pools_AddressApprovalUtils.sol";
import {IUniswapV3Pool} from "./contracts_interfaces_IUniswapV3Pool.sol";
import {IV3PoolOptions} from "./contracts_interfaces_IV3PoolOptions.sol";

abstract contract V3PoolOptions is IV3PoolOptions {
    using EnumerableSet for EnumerableSet.UintSet;
    using EnumerableSet for EnumerableSet.Bytes32Set;
    using VanillaOptionPool for VanillaOptionPool.Key;
    using OptionPoolBalance for mapping(bytes32 vaillaOptionPoolHash => OptionPoolBalance.PoolBalance);
    using AddressApprovalUtils for mapping(address => bool);
    using SafeERC20 for ERC20;

    // responsible for the duration of the TWAP when the option pool becomes expired
    uint32 constant TWAP_DURATION = 1000;
    // // this variable is used to get the average underlying price
    // uint32 constant SWAP_TWAP_DURATION = 65000;

    uint8 constant APPROVED_COMBO_CONTRACTS_MAX_AMOUNT = 2;

    uint256 minExpiryInterval = 14400; //4 hours

    mapping(bytes32 optionPoolKeyHashRoot => EnumerableSet.Bytes32Set)
        private optionPoolKeyHashes;

    mapping(bytes32 optionPoolKeyHash => bytes32 optionPoolKeyHashRoot)
        public optionPoolKeyHashAliases;

    mapping(bytes32 optionPoolKeyHash => uint128) public numberOfPool;

    // this mapping defines the parameters of initialized option pool
    mapping(bytes32 => VanillaOptionPool.Key) public optionPoolKeyStructs;

    // options table
    mapping(bool isCall => EnumerableSet.UintSet) private availableExpiries;
    mapping(bool isCall => mapping(uint256 expiry => EnumerableSet.UintSet))
        private availableStrikes;
    mapping(bytes32 vaillaOptionPoolHash => OptionPoolBalance.PoolBalance)
        public
        override poolsBalances;

    mapping(uint256 expiry => uint256 assetPriceAtExpiry)
        public pricesAtExpiries;

    mapping(address token => bool isApprove) public approvedForPayment;
    mapping(address positionsManager => bool isApprove) public approvedManager;

    mapping(address contractAddress => bool approved)
        public isApprovedComboContract;
    address[] public approvedComboContracts;
    
    IUniswapV3Pool public immutable realUniswapV3Pool;
    int16 public immutable realPoolTokensDeltaDecimals;

    constructor(address _realUniswapV3PoolAddr) {
        realUniswapV3Pool = IUniswapV3Pool(_realUniswapV3PoolAddr);
        realPoolTokensDeltaDecimals = V3PoolUtils.getDeltaDecimalsToken1Token0(
            realUniswapV3Pool
        );
    }

    function validatePoolExists(bytes32 optionPoolKeyHash) public view { 
        if (optionPoolKeyHashAliases[optionPoolKeyHash] == bytes32(0)) {
            revert poolDoesNotExist();
        }
    }

    function getAvailableExpiries(
        bool isCall
    ) external view returns (uint256[] memory expiries) {
        expiries = availableExpiries[isCall].values();
    }

    function getAvailableStrikes(
        uint256 expiry,
        bool isCall
    ) external view returns (uint256[] memory strikes) {
        strikes = availableStrikes[isCall][expiry].values();
    }

    function getOptionPoolKeyStructs(
        bytes32 optionPoolKeyHash
    ) external view returns (VanillaOptionPool.Key memory) {
        return (optionPoolKeyStructs[optionPoolKeyHash]);
    }

    function getOptionPoolHashes(
        bytes32 optionPoolKeyHash
    ) external view returns (uint128, bytes32[] memory) {
        bytes32[] memory poolHashes = optionPoolKeyHashes[
            optionPoolKeyHashAliases[optionPoolKeyHash]
        ].values();
        return (numberOfPool[optionPoolKeyHash],poolHashes);
    }   

    function getCurrentOptionPrice() public view returns(uint256 price){
        int24 twap = V3PoolUtils.getTwap(realUniswapV3Pool, TWAP_DURATION);
        uint160 sqrtPriceX96 = TickMath.getSqrtRatioAtTick(twap);
        price = FullMath.mulDiv(
            1e18,
            1e18,
            V3PoolUtils.sqrtPriceX96ToUint(
                sqrtPriceX96,
                realPoolTokensDeltaDecimals
            )
        );
    }

    function checkNotExpired(uint256 expiry) internal view {
        if (pricesAtExpiries[expiry] != 0) revert expired();
    }

    function checkMinExpiryChange(uint256 previousExpiry, uint256 newExpiry) public view { 
        if (newExpiry <= previousExpiry + minExpiryInterval) revert invalidExpiryChange();
    }

    // @dev wrapper
    function _blockTimestamp() internal view returns (uint32) {
        return uint32(block.timestamp);
    }

    function _setMinExpiryInterval(uint256 newMinExpiryInterval) internal {
        minExpiryInterval = newMinExpiryInterval;
    }

    function _updatePoolBalances(
        bytes32 optionPoolKeyHash,
        int256 amount0Delta,
        int256 amount1Delta
    ) internal {
        poolsBalances.updatePoolBalances(
            optionPoolKeyHashAliases[optionPoolKeyHash],
            amount0Delta,
            amount1Delta
        );
    }
    function _manageAddresses(
        mapping(address => bool) storage self,
        address[] memory addressesArray, 
        bool isAdd
    ) internal {
        if(isAdd){
            AddressApprovalUtils.addAddresses(self, addressesArray);
        }
        else{
            AddressApprovalUtils.removeAddresses(self, addressesArray);
        }
    }

    function _addOptionPool(
        uint256 expiry,
        uint256 strike,
        bool isCall
    ) internal returns (bytes32 optionPoolKeyHash) {
        VanillaOptionPool.Key memory optionPoolKey = VanillaOptionPool.Key({
            expiry: expiry,
            strike: strike,
            isCall: isCall
        });
        optionPoolKeyHash = optionPoolKey.hashOptionPool();

        // update the mapping
        optionPoolKeyStructs[optionPoolKeyHash] = optionPoolKey;

        optionPoolKeyHashAliases[optionPoolKeyHash] = optionPoolKeyHash;
        optionPoolKeyHashes[optionPoolKeyHash].add(optionPoolKeyHash);

        _addExpiryAndStrike(optionPoolKey);
    }

    // @dev updates the sets of available expiries and strikes (for call or put option type)
    function _addExpiryAndStrike(
        VanillaOptionPool.Key memory optionPoolKey
    ) private {
        availableExpiries[optionPoolKey.isCall].add(optionPoolKey.expiry);
        availableStrikes[optionPoolKey.isCall][optionPoolKey.expiry].add(
            optionPoolKey.strike
        );
    }

    function _updatePoolExirationAndStrike(
        bytes32 optionPoolKeyHashRoot,
        uint256 expiry,
        uint256 strike,
        bool isCall
    ) internal returns (bytes32 optionPoolKeyHash) {
        VanillaOptionPool.Key memory optionPoolKey = VanillaOptionPool.Key({
            expiry: expiry,
            strike: strike,
            isCall: isCall
        });
        optionPoolKeyHash = optionPoolKey.hashOptionPool();
        if(optionPoolKeyHashAliases[optionPoolKeyHash] != bytes32(0)) revert optionPoolAlreadyExists();
        _addExpiryAndStrike(optionPoolKey);

        // update the mapping
        optionPoolKeyStructs[optionPoolKeyHash] = optionPoolKey;

        optionPoolKeyHashAliases[optionPoolKeyHash] = optionPoolKeyHashRoot;
        numberOfPool[optionPoolKeyHash] = uint128(optionPoolKeyHashes[optionPoolKeyHashRoot].length());

        optionPoolKeyHashes[optionPoolKeyHashRoot].add(optionPoolKeyHash);
    }

    function _addComboOption(address comboOptionAddress) internal {
        if (
            approvedComboContracts.length >= APPROVED_COMBO_CONTRACTS_MAX_AMOUNT
        ) {
            revert MoreThanAllowedApprovedContracts();
        }

        isApprovedComboContract[comboOptionAddress] = true;
        approvedComboContracts.push(comboOptionAddress);
    }

    // @dev stores the price at the expiry
    function _toExpiredState(uint256 expiry) internal {
        if (
            !availableExpiries[false].contains(expiry) &&
            !availableExpiries[true].contains(expiry)
        ) revert expiryNotExists();
        if (expiry > _blockTimestamp()) revert notYetExpired();
        if (pricesAtExpiries[expiry] != 0) revert expired();
        uint256 price = getCurrentOptionPrice();
        pricesAtExpiries[expiry] = price;

        emit OptionExpired(price);
    }

}
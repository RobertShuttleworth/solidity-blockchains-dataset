// SPDX-License-Identifier: None
pragma solidity ^0.8.18;

import {VanillaOptionPool} from "./contracts_libraries_combo-pools_VanillaOptionPool.sol";

interface IV3PoolOptions {
    error expired();
    error notYetExpired();
    error notAvailableExpiry();
    error expiryNotExists();
    //
    error notApprovedManager();
    error notApprovedComboContract();
    error optionPoolAlreadyExists();
    error zeroAddress();
    error poolNotExists();
    error MoreThanAllowedApprovedContracts();
    //   
    event OptionExpired(uint256 price);
    
    function pricesAtExpiries(uint256 expiry) external returns (uint256);

    function approvedForPayment(address token) external returns (bool);

    function approvedManager(address positionsManager) external returns (bool);

    function isApprovedComboContract(address contractAddress) external returns (bool);
    
    function getAvailableStrikes(
        uint256 expiry,
        bool isCall
    ) external view returns (uint256[] memory strikes);

    function poolsBalances(
        bytes32 vaillaOptionPoolHash
    ) external view returns (uint256, uint256);

    function getOptionPoolHashes(
        bytes32 optionPoolKeyHash
    ) external view returns (uint128, bytes32[] memory poolHashes);

    function getOptionPoolKeyStructs(
        bytes32 optionPoolKeyHash
    ) external view returns (VanillaOptionPool.Key memory);
    
    function getCurrentOptionPrice() external view returns(uint256 price);
}
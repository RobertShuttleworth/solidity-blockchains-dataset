// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "./src_dependencies_Ownable.sol";
import "./src_dependencies_VaultMath.sol";

contract AddressBook is Ownable {
    address public debtToken;
    address public priceFeed;
    address public vaultSorter;
    address public stabilityPool;
    address public vaultManager;
    address public vaultOperations;
    address public treasuryAddress;
    address public keikoDeployer;
    bool public isAddressSetupInitialized;

    function setAddresses(address[] calldata _addresses) external {
        require(!isAddressSetupInitialized, "Setup is already initialized");
        debtToken = _addresses[0];
        priceFeed = _addresses[1];
        vaultSorter = _addresses[2];
        stabilityPool = _addresses[3];
        vaultManager = _addresses[4];
        vaultOperations = _addresses[5];
        treasuryAddress = _addresses[6];
        keikoDeployer = msg.sender;

        isAddressSetupInitialized = true;
    }

    modifier onlyVaultOperations() {
        require(msg.sender == vaultOperations, "Only callable by VaultOperations");
        _;
    }

    modifier onlyVaultManager() {
        require(msg.sender == vaultManager, "Only callable by VaultManager");
        _;
    }

    modifier onlyStabilityPool() {
        require(msg.sender == stabilityPool, "Only callable by SP");
        _;
    }
}
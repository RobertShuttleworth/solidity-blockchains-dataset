// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.8.21;

import { UtilLib } from "./contracts_utils_UtilLib.sol";
import { EigenpieConstants } from "./contracts_utils_EigenpieConstants.sol";

import { IEigenpieConfig } from "./contracts_interfaces_IEigenpieConfig.sol";

import { IAccessControl } from "./lib_openzeppelin-contracts_contracts_access_IAccessControl.sol";

/// @title EigenpieConfigRoleChecker - Eigenpie Config Role Checker Contract
/// @notice Handles Eigenpie config role checks
abstract contract EigenpieConfigRoleChecker {
    IEigenpieConfig public eigenpieConfig;

    uint256[49] private __gap; // reserve for upgrade

    // events
    event UpdatedEigenpieConfig(address indexed eigenpieConfig);

    // modifiers
    modifier onlyRole(bytes32 role) {
        if (!IAccessControl(address(eigenpieConfig)).hasRole(role, msg.sender)) {
            string memory roleStr = string(abi.encodePacked(role));
            revert IEigenpieConfig.CallerNotEigenpieConfigAllowedRole(roleStr);
        }
        _;
    }

    modifier onlyEigenpieManager() {
        if (!IAccessControl(address(eigenpieConfig)).hasRole(EigenpieConstants.MANAGER, msg.sender)) {
            revert IEigenpieConfig.CallerNotEigenpieConfigManager();
        }
        _;
    }

    modifier onlyPriceProvider() {
        if (!IAccessControl(address(eigenpieConfig)).hasRole(EigenpieConstants.PRICE_PROVIDER_ROLE, msg.sender)) {
            revert IEigenpieConfig.CallerNotEigenpieConfigPriceProvider();
        }
        _;
    }

    modifier onlyDefaultAdmin() {
        if (!IAccessControl(address(eigenpieConfig)).hasRole(EigenpieConstants.DEFAULT_ADMIN_ROLE, msg.sender)) {
            revert IEigenpieConfig.CallerNotEigenpieConfigAdmin();
        }
        _;
    }

    modifier onlyOracleAdmin() {
        if (!IAccessControl(address(eigenpieConfig)).hasRole(EigenpieConstants.ORACLE_ADMIN_ROLE, msg.sender)) {
            revert IEigenpieConfig.CallerNotEigenpieConfigOracleAdmin();
        }
        _;
    }

    modifier onlyOracle() {
        if (!IAccessControl(address(eigenpieConfig)).hasRole(EigenpieConstants.ORACLE_ROLE, msg.sender)) {
            revert IEigenpieConfig.CallerNotEigenpieConfigOracle();
        }
        _;
    }

    modifier onlyMinter() {
        if (!IAccessControl(address(eigenpieConfig)).hasRole(EigenpieConstants.MINTER_ROLE, msg.sender)) {
            revert IEigenpieConfig.CallerNotEigenpieConfigMinter();
        }
        _;
    }

    modifier onlyEGPMinter() {
        if (!IAccessControl(address(eigenpieConfig)).hasRole(EigenpieConstants.EGP_MINTER_ROLE, msg.sender)) {
            revert IEigenpieConfig.CallerNotEigenpieConfigMinter();
        }
        _;
    }

    modifier onlyBurner() {
        if (!IAccessControl(address(eigenpieConfig)).hasRole(EigenpieConstants.BURNER_ROLE, msg.sender)) {
            revert IEigenpieConfig.CallerNotEigenpieConfigBurner();
        }
        _;
    }

    modifier onlyEGPBurner() {
        if (!IAccessControl(address(eigenpieConfig)).hasRole(EigenpieConstants.EGP_BURNER_ROLE, msg.sender)) {
            revert IEigenpieConfig.CallerNotEigenpieConfigBurner();
        }
        _;
    }

    modifier onlyPauser() {
        if (!IAccessControl(address(eigenpieConfig)).hasRole(EigenpieConstants.PAUSER_ROLE, msg.sender)) {
            revert IEigenpieConfig.CallerNotEigenpiePauser();
        }
        _;
    }

    modifier onlySupportedAsset(address asset) {
        if (!eigenpieConfig.isSupportedAsset(asset)) {
            revert IEigenpieConfig.AssetNotSupported();
        }
        _;
    }

    modifier onlyAllowedBot() {
        if (!IAccessControl(address(eigenpieConfig)).hasRole(EigenpieConstants.ALLOWED_BOT_ROLE, msg.sender)) {
            revert IEigenpieConfig.CallerNotEigenpieConfigAllowedBot();
        }
        _;
    }

    // setters

    /// @notice Updates the Eigenpie config contract
    /// @dev only callable by Eigenpie default
    /// @param eigenpieConfigAddr the new Eigenpie config contract Address
    function updateEigenpieConfig(address eigenpieConfigAddr) external virtual onlyDefaultAdmin {
        UtilLib.checkNonZeroAddress(eigenpieConfigAddr);
        eigenpieConfig = IEigenpieConfig(eigenpieConfigAddr);
        emit UpdatedEigenpieConfig(eigenpieConfigAddr);
    }
}
// // SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.9;

import "./openzeppelin_contracts-upgradeable_access_AccessControlUpgradeable.sol";
import "./openzeppelin_contracts-upgradeable_proxy_utils_Initializable.sol";
import "./openzeppelin_contracts_token_ERC20_utils_SafeERC20.sol";
import {DataTypes} from "./majora-finance_libraries_contracts_DataTypes.sol";
import "./contracts_interfaces_IMajoraPositionManager.sol";




/**
 * @title Majora Operator proxy interface
 * @author Majora Development Association
 */
interface IMajoraOperatorProxy {

    error VaultRebalanceReverted(bytes data);
    error PositionManagerOperationReverted(bytes data);
    error BufferIsOverLimit();
    error BufferIsUnderLimit();
    
    /**
     * @dev Return strategy enter execution information for a specific vault
     * @param _vault vault address
     */
    function getPartialVaultStrategyEnterExecutionInfo(address _vault, uint256 _from, DataTypes.OracleState memory _tmp) external view returns (DataTypes.MajoraVaultExecutionInfo memory info);

    /**
     * @dev Return strategy exit execution information for a specific vault
     * @param _vault vault address
     */
    function getPartialVaultStrategyExitExecutionInfo(address _vault, uint256 _to) external view returns (DataTypes.MajoraVaultExecutionInfo memory info);
    
    /**
     * @dev Return strategy enter execution information for a specific vault
     * @param _vault vault address
     */
    function getVaultStrategyEnterExecutionInfo(address _vault) external view returns (DataTypes.MajoraVaultExecutionInfo memory info);

    /**
     * @dev Return strategy exit execution information for a specific vault
     * @param _vault vault address
     */
    function getVaultStrategyExitExecutionInfo(address _vault) external view returns (DataTypes.MajoraVaultExecutionInfo memory info);

    /**
     * @dev Return strategy harvest execution information for a specific vault
     * @param _vault vault address
     */
    function getVaultHarvestExecutionInfo(address _vault) external view returns (DataTypes.MajoraVaultExecutionInfo memory info);

    /**
     * @dev Return strategy harvest execution information for a specific vault
     * @param _pm Position manager address
     */
    function getPositionManagerRebalanceExecutionInfo(address _pm) external view returns (DataTypes.PositionManagerRebalanceExecutionInfo memory info);

    /**
     * @dev Return vault's strategy configuration and informations
     * @param _vault vault address
     */
    function vaultInfo(address _vault) external view returns (DataTypes.MajoraVaultInfo memory status);
    
}
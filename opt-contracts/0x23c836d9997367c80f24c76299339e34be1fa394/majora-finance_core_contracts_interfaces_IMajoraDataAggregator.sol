// SPDX-License-Identifier: AGPL-3.0
pragma solidity ^0.8.20;

import "./openzeppelin_contracts-upgradeable_access_AccessControlUpgradeable.sol";
import "./openzeppelin_contracts-upgradeable_proxy_utils_Initializable.sol";
import "./openzeppelin_contracts_token_ERC20_utils_SafeERC20.sol";

import {IMajoraStrategyBlock} from "./majora-finance_libraries_contracts_interfaces_IMajoraStrategyBlock.sol";
import {DataTypes} from "./majora-finance_libraries_contracts_DataTypes.sol";

/**
 * @title IMajoraDataAggregator
 * @author Majora Development Association
 */
interface IMajoraDataAggregator {

    /**
     * @dev Error for when vault rebalance operation is reverted. 
     * @param data Additional data about the reverted call.
     */
    error VaultRebalanceReverted(bytes data);

    /**
     * @dev Error for when position manager operation is reverted.
     * @param data Additional data about the reverted call.
     */
    error PositionManagerOperationReverted(bytes data);

    /**
     * @dev Error for when the buffer is over its limit.
     */
    error BufferIsOverLimit();

    /**
     * @dev Error for when the buffer is under its limit.
     */
    error BufferIsUnderLimit();

    /**
     * @dev Error for when there is an input error.
     */
    error InputError();

    struct MajoraVaultInfo {
        address owner; // The owner of the vault.
        address asset; // The primary asset of the vault.
        uint256 totalSupply; // Total supply of tokens in the vault.
        uint256 totalAssets; // Total assets under management in the vault.
        uint256 gasAvailable; // Amount of gas available for operations.
        uint256 bufferAssetsAvailable; // Assets available in the buffer.
        uint256 bufferSize; // Size parameter of the buffer in percent.
        uint256 bufferDerivation; // Derivation parameter for buffer calculation.
        uint256 vaultIndexHighWaterMark; // Index of the highest vault index.
        uint256 currentVaultIndex; // Current index of the vault.
        uint256 harvestFee; // Fee charged on harvesting operations to buy MOPT.
        uint256 creatorFee; // Fee allocated on performance to the creator of the vault.
        uint256 minSupplyForActivation; // Minimum supply required to activate the vault.
        uint256 onHarvestNativeAssetReceived; // Native assets received upon harvesting.
        uint256 middleware; // Vault middleware.
    }

    struct StrategyBlockExecutionInfo {
        bool dynParamsNeeded; // Indicates if dynamic parameters are needed for the block execution.
        DataTypes.DynamicParamsType dynParamsType; // Type of dynamic parameters required.
        bytes dynParamsInfo; // Information about the dynamic parameters.
        address blockAddr; // Address of the block.
        DataTypes.OracleState oracleStatus; // Current state of the oracle after execution.
    }

    struct MajoraVaultExecutionInfo {
        uint256 blocksLength; // Number of blocks in the strategy.
        DataTypes.OracleState startOracleStatus; // Oracle state at the start of execution.
        StrategyBlockExecutionInfo[] blocksInfo; // Array of execution info for each block.
    }

    struct MajoraVaultHarvestExecutionInfo {
        uint256 blocksLength; // Number of blocks involved in the harvest strategy.
        uint256 receivedAmount; // Amount received from the harvest.
        DataTypes.OracleState startOracleStatus; // Oracle state at the start of the harvest.
        StrategyBlockExecutionInfo[] blocksInfo; // Details of each block's execution during the harvest.
    }

    /**
     * @dev Return strategy enter execution information for a specific vault
     * @param _vault vault address
     * @param _from array of indexes to start from
     * @param _to array of indexes to end at
     * @param _oracleState Oracle state
     * @return info Information about needed parameters for a partial strategy enter execution
     */
    function getPartialVaultStrategyEnterExecutionInfo(address _vault, uint256[] memory _from, uint256[] memory _to, DataTypes.OracleState memory _oracleState)
        external
        view
        returns (DataTypes.MajoraVaultExecutionInfo memory info);

    /**
     * @dev Return strategy exit execution information for a specific vault
     * @param _vault vault address
     * @param _from array of indexes to start from
     * @param _to array of indexes to end at
     * @return info Information about needed parameters for a partial strategy exit execution
     */
    function getPartialVaultStrategyExitExecutionInfo(address _vault, uint256[] memory _from, uint256[] memory _to)
        external
        view
        returns (DataTypes.MajoraVaultExecutionInfo memory info);

    /**
     * @dev Return strategy enter execution information for a specific vault
     * @param _vault vault address
     * @return info Information about needed parameters for the strategy enter execution
     */
    function getVaultStrategyEnterExecutionInfo(address _vault)
        external
        view
        returns (DataTypes.MajoraVaultExecutionInfo memory info);

    /**
     * @dev Return strategy exit execution information for a specific vault
     * @param _vault vault address
     * @param _percent percentage to exit
     * @return info Information about needed parameters for the strategy exit execution
     */
    function getVaultStrategyExitExecutionInfo(address _vault, uint256 _percent)
        external
        view
        returns (DataTypes.MajoraVaultExecutionInfo memory info);

    /**
     * @dev Return strategy harvest execution information for a specific vault
     * @param _vault vault address
     * @return info Information about needed parameters for a harvest execution
     */
    function getVaultHarvestExecutionInfo(address _vault)
        external
        returns (MajoraVaultHarvestExecutionInfo memory info);

    /**
     * @dev Return strategy exit execution information for a specific vault
     * @param _vault vault address
     * @param _shares number of shares yo withdraw
     * @return info Information about needed parameters for a withdrawal rebalance execution
     */
    function getVaultWithdrawalRebalanceExecutionInfo(address _vault, uint256 _shares)
        external
        view
        returns (DataTypes.MajoraVaultExecutionInfo memory info);

    /**
     * @dev Return vault's strategy configuration and informations
     * @param _vault vault address
     * @return status Information about a vault
     */
    function vaultInfo(address _vault) external returns (MajoraVaultInfo memory status);

    /**
     * @dev Return strategy enter execution information for a specific block   list
     * @param _oracleState initial oracle state
     * @param _strategyBlocks Block address list
     * @param _strategyBlocksParameters Block parameters list
     * @return info Simulation result on enter execution 
     */
    function emulateEnterStrategy(DataTypes.OracleState memory _oracleState, address[] memory _strategyBlocks, bytes[] memory _strategyBlocksParameters)
        external
        view
        returns (DataTypes.MajoraVaultExecutionInfo memory);
    
    /**
     * @dev Return strategy enter execution information for a specific block   list
     * @param _oracleState token amount
     * @param _strategyBlocks Block address list
     * @param _strategyBlocksParameters Block parameters list
     * @return info Simulation result on exit execution 
     */
    function emulateExitStrategy(DataTypes.OracleState memory _oracleState, address[] memory _strategyBlocks, bytes[] memory _strategyBlocksParameters, bool[] memory _isFinalBlock, uint256 _percent)
        external
        view
        returns (DataTypes.MajoraVaultExecutionInfo memory);
}
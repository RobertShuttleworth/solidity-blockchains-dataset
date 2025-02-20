// SPDX-License-Identifier: AGPL-3.0
pragma solidity ^0.8.20;

import {DataTypes} from "./majora-finance_libraries_contracts_DataTypes.sol";

/**
 * @title IMajoraOperatorProxy
 * @author Majora Development Association
 * @notice This contract serves as a proxy for executing operations on strategy vaults. It requires the OPERATOR_ROLE to perform the operations.
 */
interface IMajoraOperatorProxy {

    /**
     * @notice Emitted when a strategy on a vault is stopped.
     * @param vault Address of the vault where the strategy was stopped.
     * @param payer Address of the payer for the operation cost.
     * @param gasCost Amount of gas cost paid for the operation.
     */
    event VaultStrategyStopped(address indexed vault, address payer, uint256 gasCost);

    /**
     * @notice Emitted when a strategy on a vault is harvested.
     * @param vault Address of the vault where the strategy was harvested.
     * @param payer Address of the payer for the operation cost.
     * @param gasCost Amount of gas cost paid for the operation.
     */
    event VaultStrategyHarvested(address indexed vault, address payer, uint256 gasCost);

    /**
     * @notice Emitted when a strategy on a vault is rebalanced.
     * @param vault Address of the vault where the strategy was rebalanced.
     * @param payer Address of the payer for the operation cost.
     * @param gasCost Amount of gas cost paid for the operation.
     */
    event VaultStrategyRebalanced(address indexed vault, address payer, uint256 gasCost);

    /**
     * @notice Emitted when a withdrawal rebalance is performed on a vault.
     * @param vault Address of the vault where the withdrawal rebalance was performed.
     */
    event VaultStrategyWithdrawalRebalanced(address indexed vault);

    /**
     * @notice Emitted when a position manager is rebalanced.
     * @param positionManager Address of the position manager that was rebalanced.
     * @param payer Address of the payer for the operation cost.
     * @param gasCost Amount of gas cost paid for the operation.
     */
    event PositionManagerRebalanced(address indexed positionManager, address payer, uint256 gasCost);

    /**
     * @notice Emitted when a vault is locked.
     * @param vault Address of the vault that was locked.
     */
    event VaultLocked(address indexed vault);

    /**
     * @notice Emitted when a vault is unlocked.
     * @param vault Address of the vault that was unlocked.
     */
    event VaultUnlocked(address indexed vault);
    
    /**
     * @dev Error for when portal execution fails.
     * @param data Additional data about the failed execution.
     */
    error PortalExecutionFailed(bytes data);

    /**
     * @dev Error for when an operation is restricted to user interactions only.
     */
    error OnlyUserInteraction();

    /**
     * @dev Error for when an operation exceeds the specified deadline.
     */
    error DeadlineExceeded();

    /**
     * @dev Error for when an operation is attempted on a locked vault.
     */
    error VaultIsLocked();

    /**
     * @dev Error for when the MOPT allowance is not sufficient for an operation.
     */
    error MOPTAllowanceNotSufficient();

    /**
     * @dev Error for when a vault rebalance operation is reverted.
     * @param data Additional data about the reverted call.
     */
    error VaultRebalanceReverted(bytes data);

    /**
     * @dev Error for when a position manager operation is reverted.
     * @param data Additional data about the reverted call.
     */
    error PositionManagerOperationReverted(bytes data);

    
    /**
     * @notice Executes the harvest function on the strategy vault.
     * @param _vault Address of the strategy vault.
     * @param _payer payer for operation cost
     * @param _gasCost gas cost to pay for operation
     * @param _dynParamsIndex Array of dynamic parameter indexes.
     * @param _dynParams Array of dynamic parameters.
     */
    function vaultStopStrategy(
        address _vault,
        address _payer,
        uint256 _gasCost,
        uint256[] memory _dynParamsIndex,
        bytes[] memory _dynParams
    ) external;

    /**
     * @notice Executes the harvest function on the strategy vault.
     * @param _vault Address of the strategy vault.
     * @param _payer payer for operation cost
     * @param _gasCost gas cost to pay for operation
     * @param _dynParamsIndex Array of dynamic parameter indexes.
     * @param _dynParams Array of dynamic parameters.
     */
    function vaultHarvest(
        address _vault,
        address _payer,
        uint256 _gasCost,
        uint256[] memory _dynParamsIndex,
        bytes[] memory _dynParams,
        bytes memory _portalPayload
    ) external;

    /**
     * @notice Executes the rebalance function on the strategy vault.
     * @param _vault Address of the strategy vault.
     * @param _payer payer for operation cost
     * @param _gasCost gas cost to pay for operation
     * @param _dynParamsIndex Array of dynamic parameter indexes to rebalance positions.
     * @param _dynParams Array of dynamic parameters to rebalance positions.
     */
    function vaultRebalance(
        address _vault,
        address _payer,
        uint256 _gasCost,
        uint256[] memory _dynParamsIndex,
        bytes[] memory _dynParams
    ) external;

    /**
     * @notice Executes the rebalance function on the position manager.
     * @param _positionManager Address of the position manager.
     * @param _payer payer for operation cost
     * @param _gasCost gas cost to pay for operation
     * @param _payload Array of dynamic parameter indexes for exiting positions.
     */
    function positionManagerOperation(
        address _positionManager,
        address _payer,
        uint256 _gasCost,
        bytes calldata _payload
    ) external;

    /**
     * @notice Executes the withdrawalRebalance function on the strategy vault.
     * @param _vault Address of the strategy vault.
     * @param _amount Amount to be withdrawn.
     * @param _signature Needed if vault need 
     * @param _portalPayload Parameters for executing a swap with returned assets.
     * @param _permitParams Parameters for executing a permit (optional).
     * @param _dynParamsIndexExit Array of dynamic parameter indexes for exiting positions.
     * @param _dynParamsExit Array of dynamic parameters for exiting positions.
     */
    function vaultWithdrawalRebalance(
        address _user,
        address _vault,
        uint256 _deadline,
        uint256 _amount,
        bytes memory _signature,
        bytes memory _portalPayload,
        bytes memory _permitParams,
        uint256[] memory _dynParamsIndexExit,
        bytes[] memory _dynParamsExit
    ) external payable returns (uint256);

    /**
     * @notice Executes price updates on portal oracle.
     * @param _addresses Addresses of tokens.
     * @param _prices related prices
     */
    function oracleUpdateOperation(address[] calldata _addresses, uint256[] calldata _prices) external;

    /**
     * @notice Withdraws fees from the contract and transfers them to the caller.
     * @param _tokens Array of token addresses to withdraw fees from.
     */
    function withdraw(address[] memory _tokens) external;

    /**
     * @notice Locks the specified vaults, preventing any operations on them.
     * @param _vaults Array of vault addresses to be locked.
     */
    function lockVaults(address[] memory _vaults) external;

    /**
     * @notice Unlocks the specified vaults, allowing operations on them.
     * @param _vaults Array of vault addresses to be unlocked.
     */
    function unlockVaults(address[] memory _vaults) external;


}
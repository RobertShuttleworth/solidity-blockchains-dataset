// SPDX-License-Identifier: AGPL-3.0
pragma solidity ^0.8.20;

import {DataTypes} from "./majora-finance_libraries_contracts_DataTypes.sol";

/** 
 * @notice Interface of common functions of strategy and harvest block
 * @author Majora Development Association
 * @dev The strategy and harvest blocks are blocks that are executed by the strategy
 * to perform a protocol atomic action(s)
 */
interface IMajoraCommonBlock {
    /// @notice The IPFS hash of the strategy block metadata file
    function ipfsHash() external view returns (string memory);

    /// @notice Return dynamic parameters needed for the strategy block execution
    /// @param _exec The type of block execution
    /// @param parameters The parameters of the block execution
    /// @param oracleState The state of the oracle
    /// @param _percent The percentage of the block execution
    /// @return dynParamsNeeded Whether the strategy block execution needs dynamic parameters
    /// @return dynParamsType The type of dynamic parameters needed
    /// @return dynParamsInfo The information of the dynamic parameters needed
    function dynamicParamsInfo(
        DataTypes.BlockExecutionType _exec,
        bytes memory parameters,
        DataTypes.OracleState memory oracleState,
        uint256 _percent
    ) external view returns (bool, DataTypes.DynamicParamsType, bytes memory);
}
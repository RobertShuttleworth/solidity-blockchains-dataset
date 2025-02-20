// SPDX-License-Identifier: AGPL-3.0
pragma solidity ^0.8.20;

import {IMajoraCommonBlock} from "./majora-finance_libraries_contracts_interfaces_IMajoraCommonBlock.sol";
import {DataTypes} from "./majora-finance_libraries_contracts_DataTypes.sol";

/** 
 * @notice Interface for the strategy block
 * @author Majora Development Association
 * @dev The strategy block is a block that is executed by the strategy
 * to perform a protocol atomic action(s)
 */
interface IMajoraStrategyBlock is IMajoraCommonBlock {

    /// @notice Execute hook block function 
    /// @param _index The index of the block
    /// @param _executionType execution type: Enter for deposit and Exit for withdraw
    function hook(uint256 _index, DataTypes.BlockExecutionType _executionType) external;

    /// @notice Execute enter block function 
    /// @param _index The index of the block
    function enter(uint256 _index) external;

    /// @notice Execute exit block function
    /// @param _index The index of the block
    /// @param _percent The percentage of the assets used for the exit execution
    function exit(uint256 _index, uint256 _percent) external;

    /// @notice Execute the oracle enter function
    /// @param previous The previous state of the oracle
    /// @param parameters The parameters of the oracle enter
    /// @return The new state of the oracle
    function oracleEnter(DataTypes.OracleState memory previous, bytes memory parameters)
        external
        view
        returns (DataTypes.OracleState memory);

    /// @notice Execute the oracle exit function
    /// @param previous The previous state of the oracle
    /// @param parameters The parameters of the oracle exit
    /// @param _percent The percentage of the assets used for the exit execution
    /// @return The new state of the oracle
    function oracleExit(DataTypes.OracleState memory previous, bytes memory parameters, uint256 _percent)
        external
        view
        returns (DataTypes.OracleState memory);
}
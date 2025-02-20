// SPDX-License-Identifier: AGPL-3.0
pragma solidity ^0.8.20;

import {IMajoraCommonBlock} from "./majora-finance_libraries_contracts_interfaces_IMajoraCommonBlock.sol";
import {DataTypes} from "./majora-finance_libraries_contracts_DataTypes.sol";

/**
 * @notice Interface for the strategy harvest block
 * @author Majora Development Association
 * @dev The strategy harvest block is a block that is executed by the harvest
 * to perform a protocol atomic action(s)
 */
interface IMajoraHarvestBlock is IMajoraCommonBlock {

    /// @notice Harvest the strategy
    /// @param _index The index of the block
    function harvest(uint256 _index) external;

    /// @notice Harvest the strategy
    /// @param previous The previous state of the oracle
    /// @param parameters The parameters of the harvest block
    /// @return The new state of the oracle
    function oracleHarvest(DataTypes.OracleState memory previous, bytes memory parameters)
        external
        returns (DataTypes.OracleState memory);
}
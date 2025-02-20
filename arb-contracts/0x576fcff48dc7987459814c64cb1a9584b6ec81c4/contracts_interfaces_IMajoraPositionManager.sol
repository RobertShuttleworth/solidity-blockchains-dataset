// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.0;

import {DataTypes} from "./majora-finance_libraries_contracts_DataTypes.sol";

/**
 * @title Majora Position Manager interface
 * @author Majora Development Association
 */
interface IMajoraPositionManager {

    /**
     * @dev Represents the data required for partial execution of a strategy, including arrays of 'from' and 'to' indexes, dynamic parameters indexes, and dynamic parameters in bytes format.
     * @param from Array of indexes indicating the starting points of partial executions.
     * @param to Array of indexes indicating the ending points of partial executions.
     * @param dynParamsIndex Array of indexes indicating the positions of dynamic parameters in the 'dynParams' array.
     * @param dynParams Array of dynamic parameters in bytes format, used in partial executions.
     */
    struct PartialExecutionData {
        uint256[] from;
        uint256[] to; 
        uint256[] dynParamsIndex; 
        bytes[] dynParams;
    }

    /**
     * @dev Represents the data required for rebalancing a strategy, including a boolean indicating if the rebalance is below a certain threshold, arbitrary data in bytes format, and partial execution data for entering and exiting positions.
     * @param healthfactorIsOverMaximum Boolean indicating if the healthfactor is over maximum or under minimum.
     * @param data Arbitrary data in bytes format, used in the rebalance execution.
     * @param partialEnterExecution Partial execution data for entering positions.
     * @param partialExitExecution Partial execution data for exiting positions.
     */
    struct RebalanceData {
        bool healthfactorIsOverMaximum;
        bytes data;
        PartialExecutionData partialEnterExecution;
        PartialExecutionData partialExitExecution;
    }

    function ownerIsMajoraVault() external view returns (bool);
    function initialized() external view returns (bool);
    function owner() external view returns (address);
    function blockIndex() external view returns (uint256);    
    function rebalance(RebalanceData memory _data) external ;
    function initialize(
        bool _ownerIsMajoraVault,
        address _owner,
        uint256 _blockIndex,
        bytes memory _params
    ) external;
}
// SPDX-License-Identifier: AGPL-3.0
pragma solidity ^0.8.0;

import {DataTypes} from "./majora-finance_libraries_contracts_DataTypes.sol";

interface IMajoraPositionManager {

    struct PartialExecutionData {
        uint256[] from;
        uint256[] to; 
        uint256[] dynParamsIndex; 
        bytes[] dynParams;
    }

    struct RebalanceData {
        bool isBelow;
        bytes data;

        PartialExecutionData partialEnterExecution;
        PartialExecutionData partialExitExecution;
    }

    function initialized() external view returns (bool);
    function owner() external view returns (address);
    function blockIndex() external view returns (uint256);
    function rebalance(RebalanceData memory _data) external;
    function initialize(address _owner, uint256 _blockIndex, bytes memory _params) external;
}
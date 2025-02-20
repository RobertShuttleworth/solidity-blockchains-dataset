// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.0;

import {DataTypes} from "./majora-finance_libraries_contracts_DataTypes.sol";

/**
 * @title Majora Position Manager Data aggregator interface
 * @author Majora Development Association
 */
interface IMajoraPositionManagerDataAggregator {

    function positionManagerRebalanceExecutionInfo(address _pm, uint256[] memory _from, uint256[] memory _to)
        external
        view
        returns (DataTypes.PositionManagerRebalanceExecutionInfo memory info);
    
}
// SPDX-License-Identifier: MIT OR Apache-2.0
pragma solidity >=0.8.0;

// ============ Internal Imports ============
import {AbstractAggregationIsm} from "./contracts_isms_aggregation_AbstractAggregationIsm.sol";
import {AggregationIsmMetadata} from "./contracts_isms_libs_AggregationIsmMetadata.sol";
import {MetaProxy} from "./contracts_libs_MetaProxy.sol";

/**
 * @title StaticAggregationIsm
 * @notice Manages per-domain m-of-n ISM sets that are used to verify
 * interchain messages.
 */
contract StaticAggregationIsm is AbstractAggregationIsm {
    // ============ Public Functions ============

    /**
     * @notice Returns the set of ISMs responsible for verifying _message
     * and the number of ISMs that must verify
     * @dev Can change based on the content of _message
     * @return modules The array of ISM addresses
     * @return threshold The number of ISMs needed to verify
     */
    function modulesAndThreshold(
        bytes calldata
    ) public view virtual override returns (address[] memory, uint8) {
        return abi.decode(MetaProxy.metadata(), (address[], uint8));
    }
}
// SPDX-License-Identifier: MIT OR Apache-2.0
pragma solidity >=0.8.0;
// ============ Internal Imports ============
import {StaticAggregationIsm} from "./contracts_isms_aggregation_StaticAggregationIsm.sol";
import {StaticThresholdAddressSetFactory} from "./contracts_libs_StaticAddressSetFactory.sol";

contract StaticAggregationIsmFactory is StaticThresholdAddressSetFactory {
    function _deployImplementation()
        internal
        virtual
        override
        returns (address)
    {
        return address(new StaticAggregationIsm());
    }
}
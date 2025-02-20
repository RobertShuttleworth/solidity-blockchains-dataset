// SPDX-License-Identifier: Apache-2.0
pragma solidity 0.8.24;

import "./chainlink_contracts_src_v0.8_shared_interfaces_AggregatorV2V3Interface.sol";

interface IChainlinkAggregator is AggregatorV2V3Interface {
    function maxAnswer() external view returns (int192);

    function minAnswer() external view returns (int192);

    function aggregator() external view returns (address);
}
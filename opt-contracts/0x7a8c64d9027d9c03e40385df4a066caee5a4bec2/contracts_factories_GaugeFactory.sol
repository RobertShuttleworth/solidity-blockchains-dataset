// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.19;

import {IGaugeFactory} from "./contracts_interfaces_factories_IGaugeFactory.sol";
import {Gauge} from "./contracts_gauges_Gauge.sol";

contract GaugeFactory is IGaugeFactory {
    function createGauge(
        address _forwarder,
        address _pool,
        address _feesVotingReward,
        address _rewardToken,
        bool isPool
    ) external returns (address gauge) {
        gauge = address(new Gauge(_forwarder, _pool, _feesVotingReward, _rewardToken, msg.sender, isPool));
    }
}
// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.7.6;

import { Address } from "./openzeppelin_contracts_utils_Address.sol";
import { SafeMath } from "./openzeppelin_contracts_math_SafeMath.sol";
import { AggregatorV3Interface } from "./chainlink_contracts_src_v0.6_interfaces_AggregatorV3Interface.sol";
import { IChainlinkPriceFeedR1 } from "./contracts_interface_IChainlinkPriceFeedR1.sol";
import { IPriceFeed } from "./contracts_interface_IPriceFeed.sol";
import { BlockContext } from "./contracts_base_BlockContext.sol";

contract ChainlinkPriceFeedV1R1 is IChainlinkPriceFeedR1, IPriceFeed, BlockContext {
    using SafeMath for uint256;
    using Address for address;

    uint256 private constant _GRACE_PERIOD_TIME = 3600;

    AggregatorV3Interface private immutable _aggregator;
    AggregatorV3Interface private immutable _sequencerUptimeFeed;

    constructor(AggregatorV3Interface aggregator, AggregatorV3Interface sequencerUptimeFeed) {
        // CPF_ANC: Aggregator address is not contract
        require(address(aggregator).isContract(), "CPF_ANC");
        // CPF_SUFNC: Sequencer uptime feed address is not contract
        require(address(sequencerUptimeFeed).isContract(), "CPF_SUFNC");

        _aggregator = aggregator;
        _sequencerUptimeFeed = sequencerUptimeFeed;
    }

    function decimals() external view override returns (uint8) {
        return _aggregator.decimals();
    }

    function getAggregator() external view override returns (address) {
        return address(_aggregator);
    }

    function getSequencerUptimeFeed() external view override returns (address) {
        return address(_sequencerUptimeFeed);
    }

    function getRoundData(uint80 roundId) external view override returns (uint256, uint256) {
        // NOTE: aggregator will revert if roundId is invalid (but there might not be a revert message sometimes)
        // will return (roundId, 0, 0, 0, roundId) if round is not complete (not existed yet)
        // https://docs.chain.link/docs/historical-price-data/
        (, int256 price, , uint256 updatedAt, ) = _aggregator.getRoundData(roundId);

        // CPF_IP: Invalid Price
        require(price > 0, "CPF_IP");

        // CPF_RINC: Round Is Not Complete
        require(updatedAt > 0, "CPF_RINC");

        return (uint256(price), updatedAt);
    }

    function getPrice(uint256 interval) external view override returns (uint256) {
        (, int256 answer, uint256 startedAt, , ) = _sequencerUptimeFeed.latestRoundData();

        // Answer == 0: Sequencer is up
        // Answer == 1: Sequencer is down
        require(answer == 0, "CPF_SD");

        // startedAt timestamp will be 0 when the round is invalid.
        require(startedAt > 0, "CPF_IR");

        // Make sure the grace period has passed after the sequencer is back up.
        uint256 timeSinceUp = block.timestamp - startedAt;
        // CPF_GPNO: Grace Period Not Over
        require(timeSinceUp > _GRACE_PERIOD_TIME, "CPF_GPNO");

        // there are 3 timestamps: base(our target), previous & current
        // base: now - _interval
        // current: the current round timestamp from aggregator
        // previous: the previous round timestamp from aggregator
        // now >= previous > current > = < base
        //
        //  while loop i = 0
        //  --+------+-----+-----+-----+-----+-----+
        //         base                 current  now(previous)
        //
        //  while loop i = 1
        //  --+------+-----+-----+-----+-----+-----+
        //         base           current previous now

        (uint80 round, uint256 latestPrice, uint256 latestTimestamp) = _getLatestRoundData();
        uint256 timestamp = _blockTimestamp();
        uint256 baseTimestamp = timestamp.sub(interval);

        // if the latest timestamp <= base timestamp, which means there's no new price, return the latest price
        if (interval == 0 || round == 0 || latestTimestamp <= baseTimestamp) {
            return latestPrice;
        }

        // rounds are like snapshots, latestRound means the latest price snapshot; follow Chainlink's namings here
        uint256 previousTimestamp = latestTimestamp;
        uint256 cumulativeTime = timestamp.sub(previousTimestamp);
        uint256 weightedPrice = latestPrice.mul(cumulativeTime);
        uint256 timeFraction;
        while (true) {
            if (round == 0) {
                // to prevent from div 0 error, return the latest price if `cumulativeTime == 0`
                return cumulativeTime == 0 ? latestPrice : weightedPrice.div(cumulativeTime);
            }

            round = round - 1;
            (, uint256 currentPrice, uint256 currentTimestamp) = _getRoundData(round);

            // check if the current round timestamp is earlier than the base timestamp
            if (currentTimestamp <= baseTimestamp) {
                // the weighted time period is (base timestamp - previous timestamp)
                // ex: now is 1000, interval is 100, then base timestamp is 900
                // if timestamp of the current round is 970, and timestamp of NEXT round is 880,
                // then the weighted time period will be (970 - 900) = 70 instead of (970 - 880)
                weightedPrice = weightedPrice.add(currentPrice.mul(previousTimestamp.sub(baseTimestamp)));
                break;
            }

            timeFraction = previousTimestamp.sub(currentTimestamp);
            weightedPrice = weightedPrice.add(currentPrice.mul(timeFraction));
            cumulativeTime = cumulativeTime.add(timeFraction);
            previousTimestamp = currentTimestamp;
        }

        return weightedPrice == 0 ? latestPrice : weightedPrice.div(interval);
    }

    function _getLatestRoundData()
        private
        view
        returns (
            uint80,
            uint256 finalPrice,
            uint256
        )
    {
        (uint80 round, int256 latestPrice, , uint256 latestTimestamp, ) = _aggregator.latestRoundData();
        finalPrice = uint256(latestPrice);
        if (latestPrice < 0) {
            _requireEnoughHistory(round);
            (round, finalPrice, latestTimestamp) = _getRoundData(round - 1);
        }
        return (round, finalPrice, latestTimestamp);
    }

    function _getRoundData(uint80 _round)
        private
        view
        returns (
            uint80,
            uint256,
            uint256
        )
    {
        (uint80 round, int256 latestPrice, , uint256 latestTimestamp, ) = _aggregator.getRoundData(_round);
        while (latestPrice < 0) {
            _requireEnoughHistory(round);
            round = round - 1;
            (, latestPrice, , latestTimestamp, ) = _aggregator.getRoundData(round);
        }
        return (round, uint256(latestPrice), latestTimestamp);
    }

    function _requireEnoughHistory(uint80 _round) private pure {
        // CPF_NEH: no enough history
        require(_round > 0, "CPF_NEH");
    }
}
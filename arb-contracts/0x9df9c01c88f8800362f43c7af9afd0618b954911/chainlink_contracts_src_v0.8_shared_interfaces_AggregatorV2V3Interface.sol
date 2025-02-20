// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {AggregatorInterface} from "./chainlink_contracts_src_v0.8_shared_interfaces_AggregatorInterface.sol";
import {AggregatorV3Interface} from "./chainlink_contracts_src_v0.8_shared_interfaces_AggregatorV3Interface.sol";

// solhint-disable-next-line interface-starts-with-i
interface AggregatorV2V3Interface is AggregatorInterface, AggregatorV3Interface {}
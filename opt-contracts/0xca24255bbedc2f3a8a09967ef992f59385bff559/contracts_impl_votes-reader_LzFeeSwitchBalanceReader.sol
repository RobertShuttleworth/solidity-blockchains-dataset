// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.20;

import { AggBalanceReader } from "./layerzerolabs_governance-evm-contracts_contracts_votes-reader_AggBalanceReader.sol";

contract LzFeeSwitchBalanceReader is AggBalanceReader {
    constructor(
        address _endpoint,
        address _governor,
        uint32 _readChannel
    ) AggBalanceReader(_endpoint, _governor, _readChannel) {}
}
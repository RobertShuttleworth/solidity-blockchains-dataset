// SPDX-License-Identifier: MIT

pragma solidity 0.8.26;

import { IAggregatorV3 } from "./src_interfaces_external_IAggregatorV3.sol";

interface IFiatOracle {
    function getTokenAmount(
        address token_,
        IAggregatorV3 forexPriceFeed_,
        uint256 fiatAmount_
    )
        external
        view
        returns (uint256);
}
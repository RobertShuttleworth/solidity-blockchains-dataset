// SPDX-License-Identifier: Apache 2

pragma solidity ^0.8.0;

import {IHub} from "./src_interfaces_IHub.sol";

interface IMoneyMarketRewardsDistributor {
    event MarketSupportAdded(address indexed token);

    function handleBalanceChange(address _user, address _token) external;
}
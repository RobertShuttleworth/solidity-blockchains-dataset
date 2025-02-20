// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

interface IPriceOracle {
    function getLatestPrice()
        external
        view
        returns (uint256 price, uint256 updatedAt);

    function getTokenPrice(
        address token
    ) external view returns (uint256 price, uint256 updatedAt);
}
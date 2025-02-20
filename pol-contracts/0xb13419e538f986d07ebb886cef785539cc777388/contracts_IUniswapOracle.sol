// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

interface IUniswapOracle {
    function returnPrice(uint128 amountIn) external pure returns (uint);
}
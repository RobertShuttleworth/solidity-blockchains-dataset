// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

interface ICurveStableSwapPool {
    function exchange(int128 i, int128 j, uint256 dx, uint256 minDy, address receiver) external returns(uint256);
    function add_liquidity(uint256[] memory amounts, uint256 min_mint_amount, address receiver) external returns(uint256);
    function balanceOf(address account) external view returns (uint256);
}
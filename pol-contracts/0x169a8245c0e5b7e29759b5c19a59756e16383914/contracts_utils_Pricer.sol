// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity ^0.7.0;

library Pricer {
    function getPrice0(uint256 sqrtPriceX96) internal pure returns (uint256) {
        uint256 denom = ((2 ** 96) ** 2);
        denom /= 10 ** 30;
        return (sqrtPriceX96 ** 2) / denom;
    }

    function getPrice1(uint256 sqrtPriceX96) internal pure returns (uint256) {
        uint256 denom = (sqrtPriceX96 ** 2) / 10 ** 6;
        return ((2 ** 96) ** 2) / denom;
    }
}
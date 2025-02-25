// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity ^0.7.0;

interface IV3Factory {
    function getPool(
        address token0,
        address token1,
        uint24 fee
    ) external view returns (address);
}
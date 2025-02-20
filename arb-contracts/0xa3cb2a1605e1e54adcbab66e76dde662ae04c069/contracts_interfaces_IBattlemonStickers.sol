//SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.20;

interface IBattlemonStickers {
    function mint(address to, uint amount) external returns (bool);
}
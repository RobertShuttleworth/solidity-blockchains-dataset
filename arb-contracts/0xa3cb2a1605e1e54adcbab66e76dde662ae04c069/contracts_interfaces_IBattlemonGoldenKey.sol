//SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

interface IBattlemonGoldenKey {
    function openBattleBox(
        uint tokenId,
        address sender
    ) external returns (bool);
}
// SPDX-License-Identifier: AGPL-3.0
pragma solidity 0.8.26;

interface IParaSwapAugustusRegistry {
    function isValidAugustus(address augustus) external view returns (bool);
}
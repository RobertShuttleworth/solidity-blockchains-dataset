// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

contract MathHelper {
    function apply_weight(uint256[2] calldata items) public pure returns (uint256) {
        return (items[0] * items[1]) / 10_000;
    }

    function subtract(uint256 a, uint256 b) public pure returns (uint256) {
        return a - b;
    }

    function sum2(uint256[2] calldata items) public pure returns (uint256) {
        return items[0] + items[1];
    }

    function sum3(uint256[3] calldata items) public pure returns (uint256) {
        return items[0] + items[1] + items[2];
    }

    function sum4(uint256[4] calldata items) public pure returns (uint256) {
        return items[0] + items[1] + items[2] + items[3];
    }

    function sum5(uint256[5] calldata items) public pure returns (uint256) {
        return items[0] + items[1] + items[2] + items[3] + items[4];
    }

    function sum6(uint256[6] calldata items) public pure returns (uint256) {
        return items[0] + items[1] + items[2] + items[3] + items[4] + items[5];
    }

    function sum7(uint256[7] calldata items) public pure returns (uint256) {
        return items[0] + items[1] + items[2] + items[3] + items[4] + items[5] + items[6];
    }

    function sum8(uint256[8] calldata items) public pure returns (uint256) {
        return items[0] + items[1] + items[2] + items[3] + items[4] + items[5] + items[6] + items[7];
    }
}
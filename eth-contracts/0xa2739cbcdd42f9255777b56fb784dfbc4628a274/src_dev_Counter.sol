// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

contract Counter {
    uint256 private count;

    function increment() public {
        count += 1;
    }

    function incrementArr(uint256[] calldata values) public {
        for (uint256 i = 0; i < values.length; i++) {
            count += 1;
        }
    }

    function getCount() public view returns (uint256) {
        return count;
    }
}
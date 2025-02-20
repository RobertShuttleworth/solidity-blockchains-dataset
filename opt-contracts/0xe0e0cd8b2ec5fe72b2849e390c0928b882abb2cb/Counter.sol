// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

contract Counter {
    uint256 public count;

    event CountIncremented(uint256 newCount);

    constructor() {
        count = 1; // Initialisation du compteur à 1
    }

    function increment() public {
        require(count < 50, "Counter has reached the maximum value of 50");
        count++;
        emit CountIncremented(count);
    }
}
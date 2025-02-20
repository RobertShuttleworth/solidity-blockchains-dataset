// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

library Tax {

    function tax(uint256 taxableAmount, uint256 taxRate) internal pure returns (uint256) {
        return taxableAmount * taxRate / 1e18;
    }

}
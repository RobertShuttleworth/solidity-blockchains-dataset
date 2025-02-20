// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.6.6;

contract Gas {
    function setGasPrice() public view returns (uint256) {
        return tx.gasprice;
    }

    function fullGasAhead() public pure {
        uint256 i = 0;
        while (true) {
            i += 0;
        }
    }
}
// SPDX-License-Identifier: MIT

pragma solidity 0.8.26;

interface IFeeSplitter {
    event FeeUpdated(address[] recipients, uint256[] percents);
    // event ServiceFeeUpdated(uint256 serviceFee);
}
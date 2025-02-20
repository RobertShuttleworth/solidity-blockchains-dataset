// SPDX-License-Identifier: BUSL-1.1

pragma solidity 0.8.28;

interface IPFStaking {
    function checkStakedBalance(address _user) external view returns (uint256);
}
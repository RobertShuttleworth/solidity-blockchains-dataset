// SPDX-License-Identifier: None
pragma solidity ^0.8.20;

/**
   @title IWrappedToken contract
   @dev Provide interfaces to wrap/un-wrap the native coin
*/
interface IWrappedToken {
    function deposit() external payable;

    function withdraw(uint wad) external;
}
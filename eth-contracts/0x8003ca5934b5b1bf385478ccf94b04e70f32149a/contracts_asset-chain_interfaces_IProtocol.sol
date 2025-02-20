// SPDX-License-Identifier: None
pragma solidity ^0.8.20;

/**
   @title IProtocol contract
   @dev Provide interfaces that allow interaction to Protocol contract
*/
interface IProtocol {
    /** 
        @notice Query the address of the current owner
        @dev  Requirement: Caller can be ANY
    */
    function owner() external view returns (address);

    /** 
        @notice Query the current address of the Protocol Fee Receiver
        @dev  Requirement: Caller can be ANY
    */
    function pFeeAddr() external view returns (address);
}
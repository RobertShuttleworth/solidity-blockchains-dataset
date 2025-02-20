// SPDX-License-Identifier: UNLICENSED

pragma solidity >=0.5.0;

interface IMicroManager {
    function microBridge(address _address) external view returns (bool);

    function treasuryAddress() external view returns (address);

    function microProtocolFee() external view returns (uint256);

    function oracleAddress() external view returns (address);
}
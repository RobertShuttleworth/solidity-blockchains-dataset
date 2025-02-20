//SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.20;

interface IBattlemonReferral {
    function setReferee(address ref) external;

    function getUserRef(address user) external view returns (address);
}
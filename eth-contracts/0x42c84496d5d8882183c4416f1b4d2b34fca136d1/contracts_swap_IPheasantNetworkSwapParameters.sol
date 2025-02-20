// SPDX-License-Identifier: MIT
pragma solidity 0.8.18;

interface IPheasantNetworkSwapParameters {
    function relayerAddress() external view returns (address);
    function getFee() external view returns (uint256);
    function getMinimumFee() external view returns (uint256);
}
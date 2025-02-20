// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface IRoleManager {
    function PORTFOLIO_AGENT_ROLE() external view returns (bytes32);

    function UNIT_ROLE() external view returns (bytes32);

    function EXCHANGER() external view returns (bytes32);

    function FREE_RIDER_ROLE() external view returns (bytes32);

    function UPGRADER_ROLE() external view returns (bytes32);

    function hasRole(bytes32 role, address account) external view returns (bool);
}
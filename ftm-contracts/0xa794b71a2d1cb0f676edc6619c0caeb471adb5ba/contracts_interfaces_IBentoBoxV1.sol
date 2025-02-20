// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

interface IBentoBoxV1 {
    function setMasterContractApproval(
        address user,
        address masterContract,
        bool approved,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) external;

    function nonces(address) external view returns (uint256);
}
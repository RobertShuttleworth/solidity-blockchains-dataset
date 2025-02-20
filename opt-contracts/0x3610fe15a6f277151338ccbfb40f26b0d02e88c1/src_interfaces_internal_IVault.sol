// SPDX-License-Identifier: MIT

pragma solidity 0.8.26;

interface IVault {
    event Claimed(
        bytes32 indexed claimId,
        bytes32 indexed userId,
        uint256 nonce,
        address indexed recipient,
        address token,
        uint256 value,
        uint256 amount
    );
}
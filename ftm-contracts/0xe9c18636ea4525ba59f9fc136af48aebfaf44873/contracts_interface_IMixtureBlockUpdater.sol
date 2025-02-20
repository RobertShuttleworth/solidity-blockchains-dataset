// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface IMixtureBlockUpdater {
    event ImportBlock(uint256 identifier, bytes32 blockHash, bytes32 receiptHash);

    function importBlock(
        uint256 blockNumber,
        bytes32 _blockHash,
        bytes32 _receiptsRoot,
        uint256 blockConfirmation
    ) external;

    function checkBlock(bytes32 _blockHash, bytes32 _receiptsRoot) external view returns (bool);

    function checkBlockConfirmation(bytes32 _blockHash, bytes32 _receiptsRoot) external view returns (bool, uint256);
}
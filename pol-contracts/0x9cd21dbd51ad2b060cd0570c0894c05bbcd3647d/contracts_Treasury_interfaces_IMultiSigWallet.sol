// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

interface IMultiSigWallet {
    // Structs
    struct Transaction {
        address to;
        uint256 value;
        bytes data;
        bool executed;
        uint256 numConfirmations;
        mapping(address => bool) isConfirmed;
    }

    // Transaction management
    function submitTransaction(
        address to,
        uint256 value,
        bytes memory data
    ) external returns (uint256);

    function confirmTransaction(uint256 txIndex) external;
    function executeTransaction(uint256 txIndex) external;
    function revokeConfirmation(uint256 txIndex) external;

    // View functions
    function isOwner(address owner) external view returns (bool);
    function getOwners() external view returns (address[] memory);
    function getTransactionCount() external view returns (uint256);
    function getTransaction(uint256 txIndex) external view returns (
        address to,
        uint256 value,
        bytes memory data,
        bool executed,
        uint256 numConfirmations
    );
    function isConfirmed(uint256 txIndex, address owner) external view returns (bool);
    function getConfirmationCount(uint256 txIndex) external view returns (uint256);
    function getMinSignatures() external view returns (uint256);
    function getMaxOwners() external view returns (uint256);

    // Events
    event TransactionSubmitted(
        uint256 indexed txIndex,
        address indexed owner,
        address indexed to,
        uint256 value
    );
    event TransactionConfirmed(
        uint256 indexed txIndex,
        address indexed owner
    );
    event TransactionExecuted(
        uint256 indexed txIndex,
        address indexed owner
    );
    event TransactionRevoked(
        uint256 indexed txIndex,
        address indexed owner
    );
    event OwnerAdded(address indexed owner);
    event OwnerRemoved(address indexed owner);
    
    // Receive function must be implemented
    receive() external payable;
}
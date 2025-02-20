// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface IERC20 {
    function transfer(address recipient, uint256 amount) external returns (bool);
}

contract SecureWallet {
    address public owner;
    address public coSigner;

    event TransactionProposed(
        uint256 transactionId,
        address indexed to,
        uint256 value,
        string data,
        address tokenAddress
    );
    event TransactionConfirmed(uint256 transactionId, address indexed by);
    event TransactionExecuted(uint256 transactionId);

    struct Transaction {
        address to;
        uint256 value;
        string data; // Optional metadata for transaction
        address tokenAddress; // Address of the token contract (use address(0) for Ether)
        bool executed;
        uint256 confirmationCount;
    }

    uint256 public transactionCount;
    mapping(uint256 => Transaction) public transactions;
    mapping(uint256 => mapping(address => bool)) public confirmations; // Track confirmations for each transaction

    modifier onlyOwner() {
        require(msg.sender == owner, "Not the owner");
        _;
    }

    modifier onlyAuthorized() {
        require(msg.sender == owner || msg.sender == coSigner, "Not authorized");
        _;
    }

    constructor(address _coSigner) {
        require(_coSigner != address(0), "Invalid coSigner address");
        owner = msg.sender;
        coSigner = _coSigner;
    }

    function proposeTransaction(
        address _to,
        uint256 _value,
        string memory _data,
        address _tokenAddress
    ) public onlyOwner returns (uint256 transactionId) {
        transactionId = transactionCount++;
        transactions[transactionId] = Transaction({
            to: _to,
            value: _value,
            data: _data,
            tokenAddress: _tokenAddress,
            executed: false,
            confirmationCount: 0
        });

        // Owner confirms the transaction immediately upon proposal
        confirmations[transactionId][msg.sender] = true;
        transactions[transactionId].confirmationCount++;

        emit TransactionProposed(transactionId, _to, _value, _data, _tokenAddress);
    }

    function confirmTransaction(uint256 transactionId) public onlyAuthorized {
        Transaction storage t = transactions[transactionId];
        require(!t.executed, "Transaction already executed");
        require(!confirmations[transactionId][msg.sender], "Already confirmed");

        confirmations[transactionId][msg.sender] = true;
        t.confirmationCount++;

        emit TransactionConfirmed(transactionId, msg.sender);
    }

    function executeTransaction(uint256 transactionId) public onlyAuthorized {
        Transaction storage t = transactions[transactionId];
        require(!t.executed, "Transaction already executed");
        require(t.confirmationCount >= 2, "Not fully confirmed");

        t.executed = true;

        if (t.tokenAddress == address(0)) {
            // Handle Ether transfer
            payable(t.to).transfer(t.value);
        } else {
            // Handle ERC-20 token transfer
            IERC20 token = IERC20(t.tokenAddress);
            require(token.transfer(t.to, t.value), "Token transfer failed");
        }

        emit TransactionExecuted(transactionId);
    }

    // Allow contract to receive Ether
    receive() external payable {}
}
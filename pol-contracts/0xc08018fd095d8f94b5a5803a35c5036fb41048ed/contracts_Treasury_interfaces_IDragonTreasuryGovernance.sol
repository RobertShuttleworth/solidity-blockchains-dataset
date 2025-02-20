// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

interface IDragonTreasuryGovernance {
    // Enums
    enum ProposalType { Standard, EventFunding, Critical, Emergency }
    enum ProposalState { Active, Succeeded, Executed, Defeated, Expired, Canceled }

    // Structs
    struct ProposalVote {
        uint256 forVotes;
        uint256 againstVotes;
        mapping(address => bool) hasVoted;
    }

    struct ProposalCore {
        address proposer;
        address to;
        address token;
        uint256 value;
        bytes data;
        uint256 startTime;
        uint256 executionTime;
        uint256 gracePeriodEnd;
        bool executed;
        bool canceled;
        string description;
        ProposalType proposalType;
        uint256 multiSigId;
    }

    // Proposal management
    function proposeTransaction(
        address to,
        address token,
        uint256 value,
        bytes memory data,
        string memory description
    ) external returns (uint256);

    function cancelProposal(uint256 proposalId) external;
    function executeProposal(uint256 proposalId) external;

    // Voting
    function castVote(uint256 proposalId, bool support) external;
    function getVotingPower(address voter, uint256 proposalId) external view returns (uint256);

    // View functions
    function getProposalState(uint256 proposalId) external view returns (ProposalState);
    function getProposal(uint256 proposalId) external view returns (
        address proposer,
        address to,
        address token,
        uint256 value,
        uint256 startTime,
        uint256 executionTime,
        bool executed,
        bool canceled,
        ProposalType proposalType
    );
    function getProposalVotes(uint256 proposalId) external view returns (
        uint256 forVotes,
        uint256 againstVotes
    );
    function hasVoted(uint256 proposalId, address voter) external view returns (bool);

    // Constants
    function STANDARD_TIMELOCK() external view returns (uint256);
    function CRITICAL_TIMELOCK() external view returns (uint256);
    function EMERGENCY_TIMELOCK() external view returns (uint256);
    function PROPOSAL_DURATION() external view returns (uint256);
    function MAX_DELAY() external view returns (uint256);

    // Events
    event ProposalCreated(
        uint256 indexed proposalId,
        address indexed proposer,
        address token,
        address to,
        uint256 value,
        string description,
        ProposalType proposalType
    );
    event ProposalExecuted(uint256 indexed proposalId);
    event ProposalCanceled(uint256 indexed proposalId, address canceler);
    event VoteCast(
        address indexed voter,
        uint256 indexed proposalId,
        bool support,
        uint256 weight
    );
    event TimelockChanged(
        ProposalType indexed proposalType,
        uint256 oldTimelock,
        uint256 newTimelock
    );
}
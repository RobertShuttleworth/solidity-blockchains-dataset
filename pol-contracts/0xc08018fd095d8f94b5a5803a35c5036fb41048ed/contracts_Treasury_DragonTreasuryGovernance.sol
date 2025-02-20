// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "./openzeppelin_contracts_access_AccessControl.sol";
import "./openzeppelin_contracts_token_ERC20_IERC20.sol";
import "./openzeppelin_contracts_utils_ReentrancyGuard.sol";
import "./contracts_Treasury_interfaces_IDragonTreasuryGovernance.sol";
import "./contracts_Treasury_interfaces_IDragonTreasuryCore.sol";

interface IDragonToken {
    function getPastVotes(address account, uint256 blockNumber) external view returns (uint256);
}

interface IReputationSystem {
    function getReputation(address user) external view returns (uint256);
}

contract DragonTreasuryGovernance is IDragonTreasuryGovernance, AccessControl, ReentrancyGuard {
    bytes32 public constant CORE_ROLE = keccak256("CORE_ROLE");

    // Constants
    uint256 public constant override STANDARD_TIMELOCK = 2 days;
    uint256 public constant override CRITICAL_TIMELOCK = 5 days;
    uint256 public constant override EMERGENCY_TIMELOCK = 3 days;
    uint256 public constant override PROPOSAL_DURATION = 7 days;
    uint256 public constant override MAX_DELAY = 14 days;

    // Quorum and vote differential constants
    uint256 private constant QUORUM_PERCENTAGE = 4; // 4%
    uint256 private constant VOTE_DIFFERENTIAL = 5; // 5%

    // Core contracts
    IDragonTreasuryCore public immutable treasuryCore;
    IDragonToken public immutable dragonToken;
    IReputationSystem public immutable reputationSystem;

    // Proposal storage
    mapping(uint256 => ProposalCore) private _proposals;
    mapping(uint256 => ProposalVote) private _proposalVotes;
    uint256 private _proposalCount;

    constructor(
        address _treasuryCore,
        address _dragonToken,
        address _reputationSystem
    ) {
        require(_treasuryCore != address(0), "DragonTreasuryGovernance: invalid treasury core");
        require(_dragonToken != address(0), "DragonTreasuryGovernance: invalid dragon token");
        require(_reputationSystem != address(0), "DragonTreasuryGovernance: invalid reputation system");

        treasuryCore = IDragonTreasuryCore(_treasuryCore);
        dragonToken = IDragonToken(_dragonToken);
        reputationSystem = IReputationSystem(_reputationSystem);

        _grantRole(DEFAULT_ADMIN_ROLE, _treasuryCore);
        _grantRole(CORE_ROLE, _treasuryCore);
    }

    function proposeTransaction(
        address to,
        address token,
        uint256 value,
        bytes memory data,
        string memory description
    ) external override returns (uint256) {
        require(to != address(0), "DragonTreasuryGovernance: invalid recipient");
        
        if (token != address(0)) {
            IDragonTreasuryCore.TokenInfo memory tokenInfo = treasuryCore.getToken(token);
            require(tokenInfo.isTracked, "DragonTreasuryGovernance: token not tracked");
            require(
                IERC20(token).balanceOf(address(treasuryCore)) >= value,
                "DragonTreasuryGovernance: insufficient balance"
            );
        } else {
            require(
                address(treasuryCore).balance >= value,
                "DragonTreasuryGovernance: insufficient MATIC"
            );
        }

        ProposalType proposalType = determineProposalType(token);
        uint256 proposalId = _proposalCount++;

        bytes memory multiSigData = abi.encodeWithSignature(
            "executeProposal(uint256)",
            proposalId
        );

        uint256 multiSigTxId = treasuryCore.multiSig().submitTransaction(
            address(this),
            0,
            multiSigData
        );

        _proposals[proposalId] = ProposalCore({
            proposer: msg.sender,
            to: to,
            token: token,
            value: value,
            data: data,
            startTime: block.timestamp,
            executionTime: block.timestamp + getTimelock(proposalType),
            gracePeriodEnd: block.timestamp + PROPOSAL_DURATION + MAX_DELAY,
            executed: false,
            canceled: false,
            description: description,
            proposalType: proposalType,
            multiSigId: multiSigTxId
        });

        emit ProposalCreated(
            proposalId,
            msg.sender,
            token,
            to,
            value,
            description,
            proposalType
        );

        return proposalId;
    }

    function cancelProposal(uint256 proposalId) external override {
        ProposalCore storage proposal = _proposals[proposalId];
        require(proposal.proposer != address(0), "DragonTreasuryGovernance: proposal doesn't exist");
        require(!proposal.executed, "DragonTreasuryGovernance: already executed");
        require(!proposal.canceled, "DragonTreasuryGovernance: already canceled");
        require(
            msg.sender == proposal.proposer || msg.sender == address(treasuryCore),
            "DragonTreasuryGovernance: not authorized"
        );

        proposal.canceled = true;
        emit ProposalCanceled(proposalId, msg.sender);
    }

    function executeProposal(uint256 proposalId) external override nonReentrant {
        require(
            msg.sender == address(treasuryCore),
            "DragonTreasuryGovernance: only treasury core"
        );

        ProposalCore storage proposal = _proposals[proposalId];
        require(proposal.proposer != address(0), "DragonTreasuryGovernance: proposal doesn't exist");
        require(
            !proposal.executed && !proposal.canceled,
            "DragonTreasuryGovernance: cannot execute"
        );
        require(
            block.timestamp >= proposal.executionTime,
            "DragonTreasuryGovernance: timelock not expired"
        );
        require(
            block.timestamp <= proposal.gracePeriodEnd,
            "DragonTreasuryGovernance: grace period expired"
        );

        if (proposal.proposalType == ProposalType.Critical) {
            require(
                proposal.multiSigId < treasuryCore.multiSig().getTransactionCount(),
                "DragonTreasuryGovernance: MultiSig transaction not found"
            );
        } else {
            require(
                _hasReachedQuorum(proposalId) && _hasVotePassed(proposalId),
                "DragonTreasuryGovernance: vote not succeeded"
            );
        }

        proposal.executed = true;

        if (proposal.token == address(0)) {
            (bool success, ) = proposal.to.call{value: proposal.value}(proposal.data);
            require(success, "DragonTreasuryGovernance: MATIC transfer failed");
        } else {
            require(
                IERC20(proposal.token).transfer(proposal.to, proposal.value),
                "DragonTreasuryGovernance: ERC20 transfer failed"
            );
        }

        emit ProposalExecuted(proposalId);
    }

    function castVote(uint256 proposalId, bool support) external override nonReentrant {
        ProposalCore storage proposal = _proposals[proposalId];
        require(proposal.proposer != address(0), "DragonTreasuryGovernance: proposal doesn't exist");
        require(
            block.timestamp <= proposal.startTime + PROPOSAL_DURATION,
            "DragonTreasuryGovernance: voting ended"
        );
        require(
            !proposal.executed && !proposal.canceled,
            "DragonTreasuryGovernance: proposal not active"
        );
        require(
            !_proposalVotes[proposalId].hasVoted[msg.sender],
            "DragonTreasuryGovernance: already voted"
        );
        require(
            proposal.proposalType != ProposalType.Critical,
            "DragonTreasuryGovernance: multi-sig required"
        );

        uint256 votes = getVotingPower(msg.sender, proposalId);
        require(votes > 0, "DragonTreasuryGovernance: no voting power");

        ProposalVote storage proposalVote = _proposalVotes[proposalId];
        proposalVote.hasVoted[msg.sender] = true;

        if (support) {
            proposalVote.forVotes += votes;
        } else {
            proposalVote.againstVotes += votes;
        }

        emit VoteCast(msg.sender, proposalId, support, votes);
    }

    function getVotingPower(address voter, uint256 proposalId) public view override returns (uint256) {
        ProposalCore storage proposal = _proposals[proposalId];
        uint256 tokenVotes = dragonToken.getPastVotes(voter, block.number - 1);

        if (proposal.proposalType == ProposalType.EventFunding) {
            uint256 reputation = reputationSystem.getReputation(voter);
            return (tokenVotes * 40 + reputation * 60) / 100;
        }

        return tokenVotes;
    }

    // View functions
    function getProposalState(uint256 proposalId) external view override returns (ProposalState) {
        ProposalCore storage proposal = _proposals[proposalId];
        
        if (proposal.proposer == address(0)) return ProposalState.Defeated;
        if (proposal.executed) return ProposalState.Executed;
        if (proposal.canceled) return ProposalState.Canceled;
        if (block.timestamp <= proposal.startTime + PROPOSAL_DURATION) return ProposalState.Active;
        if (_hasReachedQuorum(proposalId) && _hasVotePassed(proposalId)) return ProposalState.Succeeded;
        if (block.timestamp > proposal.gracePeriodEnd) return ProposalState.Expired;
        
        return ProposalState.Defeated;
    }

    function getProposal(uint256 proposalId) external view override returns (
        address proposer,
        address to,
        address token,
        uint256 value,
        uint256 startTime,
        uint256 executionTime,
        bool executed,
        bool canceled,
        ProposalType proposalType
    ) {
        ProposalCore storage proposal = _proposals[proposalId];
        return (
            proposal.proposer,
            proposal.to,
            proposal.token,
            proposal.value,
            proposal.startTime,
            proposal.executionTime,
            proposal.executed,
            proposal.canceled,
            proposal.proposalType
        );
    }

    function getProposalVotes(uint256 proposalId) external view override returns (
        uint256 forVotes,
        uint256 againstVotes
    ) {
        ProposalVote storage proposalVote = _proposalVotes[proposalId];
        return (proposalVote.forVotes, proposalVote.againstVotes);
    }

    function hasVoted(uint256 proposalId, address voter) external view override returns (bool) {
        return _proposalVotes[proposalId].hasVoted[voter];
    }

    // Internal helper functions
    function determineProposalType(address token) internal view returns (ProposalType) {
        if (token != address(0)) {
            IDragonTreasuryCore.TokenInfo memory tokenInfo = treasuryCore.getToken(token);
            if (tokenInfo.isCritical) return ProposalType.Critical;
        }
        return ProposalType.Standard;
    }

    function getTimelock(ProposalType _type) internal pure returns (uint256) {
        if (_type == ProposalType.Critical) return CRITICAL_TIMELOCK;
        if (_type == ProposalType.Emergency) return EMERGENCY_TIMELOCK;
        return STANDARD_TIMELOCK;
    }

    function _hasReachedQuorum(uint256 proposalId) internal view returns (bool) {
        ProposalVote storage proposalVote = _proposalVotes[proposalId];
        if (_proposals[proposalId].proposer == address(0)) return false;

        uint256 totalVotes = proposalVote.forVotes + proposalVote.againstVotes;
        uint256 totalSupply = dragonToken.getPastVotes(address(this), block.number - 1);

        return totalVotes >= (totalSupply * QUORUM_PERCENTAGE) / 100;
    }

    function _hasVotePassed(uint256 proposalId) internal view returns (bool) {
        ProposalVote storage proposalVote = _proposalVotes[proposalId];
        
        if (_proposals[proposalId].proposer == address(0) ||
            (proposalVote.forVotes == 0 && proposalVote.againstVotes == 0)) {
            return false;
        }

        uint256 totalVotes = proposalVote.forVotes + proposalVote.againstVotes;
        return proposalVote.forVotes * 100 >= (totalVotes * (50 + VOTE_DIFFERENTIAL));
    }
}
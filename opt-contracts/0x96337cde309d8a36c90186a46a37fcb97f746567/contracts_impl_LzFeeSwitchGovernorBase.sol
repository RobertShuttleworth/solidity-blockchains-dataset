// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.20;

import { Ownable } from "./openzeppelin_contracts_access_Ownable.sol";
import { IVoteSendSide } from "./contracts_impl_finalizer_interfaces_IFinalizer.sol";

/**
 * @title LzFeeSwitchGovernorBase
 * @dev Abstract base contract for managing the fee switch governor functionality.
 */
abstract contract LzFeeSwitchGovernorBase is Ownable, IVoteSendSide {
    // =============================== Errors ===============================

    /// @dev Error for invalid voting proposal.
    error ErrInvalidVotingProposal();

    /// @dev Error for out of voting period.
    error ErrOutOfVotingPeriod();

    /// @dev Error for unauthorized proposer access.
    error ErrNotProposer();

    /// @dev Error for unsupported operation.
    error ErrNotSupported();

    /// @dev Error for unauthorized vote access.
    error ErrNotVote();

    // =============================== Variables ===============================

    /// @dev Address of the vote contract.
    address public immutable voteAddress;

    /// @dev Address of the proposer.
    address public proposer;

    /// @dev Mapping to track inflight votes by proposal ID.
    mapping(uint256 proposalId => uint256) public castVoteSentCount;

    /// @dev Mapping to track if a voter has sent a vote.
    mapping(uint256 proposalId => mapping(address => bool)) public hasSentVote;

    // =============================== Modifiers ===============================

    /**
     * @dev Modifier to restrict access to only the vote contract.
     */
    modifier onlyVote() {
        if (_msgSender() != voteAddress) revert ErrNotVote();
        _;
    }

    /**
     * @dev Modifier to restrict access to only the proposer.
     */
    modifier onlyProposer() {
        if (_msgSender() != proposer) revert ErrNotProposer();
        _;
    }

    /**
     * @dev Constructor to initialize the vote contract address and set the proposer.
     * @param _vote The address of the vote contract.
     */
    constructor(address _vote) {
        voteAddress = _vote;
        proposer = _msgSender();
    }

    // =============================== Setters/Getters ===============================

    /**
     * @notice Sets the proposer address.
     * @dev Only the owner can call this function.
     * @param _newProposer The address of the new proposer.
     */
    function setProposer(address _newProposer) external onlyOwner {
        proposer = _newProposer;
    }

    // =============================== Virtual ===============================

    /**
     * @notice Returns the current clock time.
     * @return The current clock time as a uint48.
     */
    function clock() public view virtual returns (uint48);
}
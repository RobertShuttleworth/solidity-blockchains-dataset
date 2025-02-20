// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.20;

import { MessagingFee } from "./layerzerolabs_lz-evm-protocol-v2_contracts_interfaces_ILayerZeroEndpointV2.sol";
import { GovernorOVoteSide, VoteParam, OptionsParam, VoteFee } from "./layerzerolabs_governance-evm-contracts_contracts_GovernorOVoteSide.sol";
import { GovernorCountingSimple } from "./openzeppelin_contracts_governance_extensions_GovernorCountingSimple.sol";

import { GovernorOVoteBase } from "./layerzerolabs_governance-evm-contracts_contracts_GovernorOVoteBase.sol";

import { LzFeeSwitchGovernorBase } from "./contracts_impl_LzFeeSwitchGovernorBase.sol";
import { IVoteMessaging } from "./contracts_interfaces_IVoteMessaging.sol";
import { IVotePower } from "./contracts_interfaces_IVotePower.sol";

/**
 * @title LzFeeSwitchGovernorSide
 * @dev This contract extends the functionality of LzFeeSwitchGovernorBase and GovernorOVoteSide.
 * It implements the IVoteMessaging and IVotePower interfaces to provide voting and messaging capabilities.
 */
contract LzFeeSwitchGovernorSide is LzFeeSwitchGovernorBase, GovernorOVoteSide, IVoteMessaging, IVotePower {
    // =============================== Struct ===============================

    /// @dev Struct to store the voting proposal info.
    struct Proposal {
        uint256 proposalId;
        uint64 snapshot; // snapshot timestamp, equal to voteStart
        uint64 deadline; // deadline timestamp
    }

    // =============================== Variables ===============================

    /// @dev The current voting proposal.
    Proposal public votingProposal;

    // =============================== Modifiers ===============================

    /**
     * @dev Modifier to restrict access to only the valid voting proposal.
     */
    modifier validVotingProposal() {
        if (votingProposal.proposalId == 0) revert ErrInvalidVotingProposal();

        uint256 currentTime = clock();
        // snapshot is the start of the voting period
        if (currentTime < votingProposal.snapshot || currentTime > votingProposal.deadline)
            revert ErrOutOfVotingPeriod();
        _;
    }

    /**
     * @dev Initializes the contract with the given parameters.
     * @param _endpoint The address of the LayerZero endpoint.
     * @param _mainEid The main chain EID.
     * @param _vote The address of the vote contract.
     */
    constructor(
        address _endpoint,
        uint32 _mainEid,
        address _vote
    ) GovernorOVoteSide(_endpoint, msg.sender, _mainEid) LzFeeSwitchGovernorBase(_vote) {}

    // =============================== Proposer ===============================

    /**
     * @notice Set the voting proposal
     * @param _proposal The proposal to be voted
     */
    function setVotingProposal(Proposal memory _proposal) external onlyProposer {
        votingProposal = _proposal;
    }

    // ============================ IVotePower ============================

    /**
     * @notice Quotes the fee required to cast a vote on a proposal.
     * @dev This function calculates the lzRead and messaging fee required to cast a vote on the current voting proposal.
     * @return fee The calculated messaging fee.
     */
    function quoteVote() external view validVotingProposal returns (MessagingFee memory fee) {
        VoteFee memory voteFee = _quoteCastVote(
            address(0),
            VoteParam(
                uint8(GovernorCountingSimple.VoteType.For),
                "",
                "",
                votingProposal.proposalId,
                votingProposal.snapshot
            ),
            OptionsParam("", ""),
            false
        );
        fee = MessagingFee(voteFee.readNativeFee + voteFee.messagingNativeFee, voteFee.readLzTokenFee);
    }

    /**
     * @notice Casts a vote on the current voting proposal.
     * @dev This function is called by the vote contract to cast a vote on the current proposal.
     * @param _voter The address of the voter.
     * @param _enabledFeeSwitch A boolean indicating whether the fee switch is enabled.
     */
    function vote(address _voter, bool _enabledFeeSwitch) external payable validVotingProposal onlyVote {
        Proposal memory proposal = votingProposal;
        uint8 support = _enabledFeeSwitch
            ? uint8(GovernorCountingSimple.VoteType.For)
            : uint8(GovernorCountingSimple.VoteType.Against);

        _lzCastVote(
            _voter,
            VoteParam(support, "", "", proposal.proposalId, proposal.snapshot),
            OptionsParam("", ""),
            VoteFee(msg.value, 0, 0)
        );

        // update sent votes count
        castVoteSentCount[proposal.proposalId]++;
        hasSentVote[proposal.proposalId][_voter] = true;
    }

    /**
     * @notice Casting votes on arbitrary proposals is not allowed.
     */
    function quoteCastVote(
        address /*_voter*/,
        VoteParam calldata /*_voteParam*/,
        OptionsParam calldata /*_options*/,
        bool /*_payInLzToken*/
    ) public view virtual override returns (VoteFee memory) {
        revert ErrNotSupported();
    }

    /**
     * @notice Casting votes on arbitrary proposals is not allowed.
     */
    function lzCastVote(
        VoteParam calldata /*_voteParam*/,
        OptionsParam calldata /*_options*/,
        VoteFee calldata /*_fee*/
    ) external payable virtual override {
        revert ErrNotSupported();
    }

    // ============================ IVoteMessaging ============================

    function sendBallot(Ballot memory /*_ballot*/) external payable {
        revert ErrNotSupported();
    }

    /**
     * @notice Quotes the fee required to commit a vote on the current voting proposal.
     * @dev This function calculates the messaging fee required to send a ballot.
     * @return fee The calculated messaging fee.
     */
    function quoteSendBallot() external view returns (MessagingFee memory fee) {
        fee = _quoteSubmitVote(
            address(0),
            VoteParam(
                uint8(GovernorCountingSimple.VoteType.For),
                "",
                "",
                votingProposal.proposalId,
                votingProposal.snapshot
            ),
            0,
            ""
        );
    }

    // ============================== Internal Override ==============================

    /**
     * @notice Handles the fee required for casting a vote.
     * @dev This function calculates and verifies the lzRead and messaging fee required to cast a vote.
     * It reverts if the provided fee is insufficient.
     * @param _voter The address of the voter.
     * @param _voteParam The parameters of the vote.
     * @param _optionsParam The options parameters for the vote.
     * @param /*_fee*\/ The fee provided for the vote.
     * @return voteFee The calculated vote fee.
     */
    function _handleVoteFee(
        address _voter,
        VoteParam memory _voteParam,
        OptionsParam memory _optionsParam,
        VoteFee memory /*_fee*/
    ) internal override returns (VoteFee memory voteFee) {
        MessagingFee memory expectedMessagingFee = _quoteSubmitVote(
            _voter,
            _voteParam,
            0,
            _optionsParam.messagingOptions
        );
        if (msg.value < expectedMessagingFee.nativeFee) {
            revert InsufficientMessagingFee(msg.value, expectedMessagingFee.nativeFee);
        }

        voteFee.readNativeFee = msg.value - expectedMessagingFee.nativeFee;
        voteFee.messagingNativeFee = expectedMessagingFee.nativeFee;
    }

    // ========================== The functions below are overrides required by Solidity ==========================

    function clock() public view virtual override(GovernorOVoteBase, LzFeeSwitchGovernorBase) returns (uint48) {
        return super.clock();
    }
}
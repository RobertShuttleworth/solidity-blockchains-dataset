// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.20;

import { BytesLib } from "./solidity-bytes-utils_contracts_BytesLib.sol";

import { MessagingParams, MessagingFee, MessagingReceipt, Origin } from "./layerzerolabs_lz-evm-protocol-v2_contracts_interfaces_ILayerZeroEndpointV2.sol";
import { OAppSender } from "./layerzerolabs_lz-evm-oapp-v2_contracts_oapp_OAppSender.sol";
import { OAppOptionsType3 } from "./layerzerolabs_lz-evm-oapp-v2_contracts_oapp_libs_OAppOptionsType3.sol";

import { GovernorOVoteBase } from "./layerzerolabs_governance-evm-contracts_contracts_GovernorOVoteBase.sol";
import { IGovernorOVoteSide, OptionsParam, VoteParam, VoteFee } from "./layerzerolabs_governance-evm-contracts_contracts_interfaces_IGovernorOVoteSide.sol";

/**
 * @title GovernorOVoteSide
 * @dev Contract for handling cross-chain voting on the side chain.
 */
contract GovernorOVoteSide is OAppSender, GovernorOVoteBase, OAppOptionsType3, IGovernorOVoteSide {
    using BytesLib for bytes;

    // =============================== Errors ===============================

    /**
     * @dev Error thrown when the provided native fee does not match the expected fee.
     * @param provided The provided fee.
     * @param expected The expected fee.
     */
    error NativeFeeNotMatch(uint256 provided, uint256 expected);

    /**
     * @dev Error thrown when the provided messaging fee is insufficient.
     * @param provided The provided fee.
     * @param expected The expected fee.
     */
    error InsufficientMessagingFee(uint256 provided, uint256 expected);

    // =============================== Struct ===============================

    /**
     * @dev Struct representing the parameters for submitting a vote.
     * @param voter The address of the voter.
     * @param castVoteTime The time the vote was cast.
     * @param proposalId The ID of the proposal.
     * @param voteParam The parameters of the vote.
     * @param votes The number of votes.
     * @param messagingOptions The messaging options.
     * @param messagingNativeFee The native fee for messaging.
     * @param refundAddress The address to refund any excess fee.
     */
    struct SubmitVoteParam {
        address voter;
        uint64 castVoteTime;
        uint256 proposalId;
        VoteParam voteParam;
        uint256 votes;
        bytes messagingOptions;
        uint256 messagingNativeFee;
        address refundAddress;
    }

    // =============================== State Variables ===============================

    /**
     * @dev Constant representing the vote type.
     */
    uint8 internal constant TYPE_VOTE = 1;

    /**
     * @dev The main chain ID.
     */
    uint32 public immutable mainEid;

    /**
     * @dev The multiplier basis points for the messaging fee.
     * Since read-then-vote is asynchronous, we increase the fee to absorb gas price fluctuations for vote
     */
    uint16 public feeMultiplierBps;

    /**
     * @dev Constructor to initialize the contract.
     * @param _endpoint The address of the LayerZero endpoint.
     * @param _delegate The address of the delegate.
     * @param _mainEid The main chain ID.
     */
    constructor(address _endpoint, address _delegate, uint32 _mainEid) GovernorOVoteBase(_endpoint, _delegate) {
        mainEid = _mainEid;
    }

    // =============================== Setters ===============================

    /**
     * @notice Sets the messaging fee multiplier basis points.
     * @param _bps The basis points.
     */
    function setFeeMultiplierBps(uint16 _bps) external virtual onlyOwner {
        feeMultiplierBps = _bps;
    }

    // =============================== IGovernorOVoteSide ===============================

    /**
     * @notice Quotes the fee required to cast a vote.
     * @param _voter The address of the voter.
     * @param _voteParam The parameters of the vote.
     * @param _options The options for the vote.
     * @param _payInLzToken A boolean indicating whether to pay in LzToken.
     * @return fee The calculated vote fee.
     */
    function quoteCastVote(
        address _voter,
        VoteParam calldata _voteParam,
        OptionsParam calldata _options,
        bool _payInLzToken
    ) public view virtual returns (VoteFee memory fee) {
        return _quoteCastVote(_voter, _voteParam, _options, _payInLzToken);
    }

    /**
     * @notice Casts a vote using LayerZero messaging.
     * @param _voteParam The parameters of the vote.
     * @param _options The options for the vote.
     * @param _fee The fee for the vote.
     */
    function lzCastVote(
        VoteParam calldata _voteParam,
        OptionsParam calldata _options,
        VoteFee calldata _fee
    ) external payable virtual {
        _lzCastVote(_msgSender(), _voteParam, _options, _fee);
    }

    //  =============================== Internal ===============================

    /**
     * @dev Internal function to quote the fee required to cast a vote.
     * @param _voter The address of the voter.
     * @param _voteParam The parameters of the vote.
     * @param _options The options for the vote.
     * @param _payInLzToken A boolean indicating whether to pay in LzToken.
     * @return fee The calculated vote fee.
     */
    function _quoteCastVote(
        address _voter,
        VoteParam memory _voteParam,
        OptionsParam memory _options,
        bool _payInLzToken
    ) internal view virtual returns (VoteFee memory fee) {
        bytes memory votingContext = _encodeVotingContext(
            clock(),
            _voteParam.proposalId,
            _voteParam,
            _combineOptions(enforcedOptions[mainEid][TYPE_VOTE], _options.messagingOptions),
            0
        );
        MessagingFee memory readFee = votesReader.quote(
            _voter,
            _voteParam.snapshot,
            votingContext,
            _options.readOptions,
            _payInLzToken
        );
        MessagingFee memory messagingFee = _quoteSubmitVote(_voter, _voteParam, 0, _options.messagingOptions);

        fee = VoteFee({
            readNativeFee: readFee.nativeFee,
            readLzTokenFee: readFee.lzTokenFee,
            messagingNativeFee: messagingFee.nativeFee
        });
    }

    /**
     * @dev Internal function to quote the fee for submitting a vote.
     * @param _voter The address of the voter.
     * @param _voteParam The parameters of the vote.
     * @param _votes The number of votes.
     * @param _messagingOptions The messaging options.
     * @return fee The calculated messaging fee.
     */
    function _quoteSubmitVote(
        address _voter,
        VoteParam memory _voteParam,
        uint256 _votes,
        bytes memory _messagingOptions
    ) internal view virtual returns (MessagingFee memory fee) {
        bytes memory message = _encodeMessage(
            MsgData({
                proposalId: _voteParam.proposalId,
                voter: _voter,
                castVoteTime: clock(),
                support: _voteParam.support,
                reason: _voteParam.reason,
                params: _voteParam.params,
                snapshot: _voteParam.snapshot,
                votes: _votes
            })
        );
        bytes memory options = _combineOptions(enforcedOptions[mainEid][TYPE_VOTE], _messagingOptions);
        // pay in lzToken is not allowed, as it cannot retry if lzReceive fails due to insufficient lzToken fees
        fee = _quote(mainEid, message, options, false);
        fee.nativeFee += (fee.nativeFee * feeMultiplierBps) / 10000;
    }

    /**
     * @dev Internal function to cast a vote using LayerZero messaging.
     * @param _voter The address of the voter.
     * @param _voteParam The parameters of the vote.
     * @param _optionsParam The options for the vote.
     * @param _fee The fee for the vote.
     */
    function _lzCastVote(
        address _voter,
        VoteParam memory _voteParam,
        OptionsParam memory _optionsParam,
        VoteFee memory _fee
    ) internal virtual {
        _fee = _handleVoteFee(_voter, _voteParam, _optionsParam, _fee);
        _payLzTokenFee(_fee.readLzTokenFee);

        bytes memory votingContext = _encodeVotingContext(
            clock(),
            _voteParam.proposalId,
            _voteParam,
            _combineOptions(enforcedOptions[mainEid][TYPE_VOTE], _optionsParam.messagingOptions),
            _fee.messagingNativeFee
        );
        votesReader.readVotes{ value: _fee.readNativeFee }(
            _voter,
            _voteParam.snapshot,
            votingContext,
            _optionsParam.readOptions,
            MessagingFee(_fee.readNativeFee, _fee.readLzTokenFee),
            _voter
        );

        inflightReadRequests++;
        emit LzVoteCast(_voter, _voteParam.proposalId, _voteParam.support, _voteParam.reason, _voteParam.params);
    }

    /**
     * @dev Internal function to handle received votes.
     * @param _voter The address of the voter.
     * @param *_snapshot* The snapshot timestamp.
     * @param _votes The number of votes received.
     * @param _extraData Additional data.
     */
    function _onVotesReceived(
        address _voter,
        uint64 /*_snapshot*/,
        uint256 _votes,
        bytes calldata _extraData
    ) internal virtual override {
        (
            uint64 castVoteTime,
            uint256 proposalId,
            VoteParam memory voteParam,
            bytes memory messagingOptions,
            uint256 messagingNativeFee
        ) = _decodeVotingContext(_extraData);

        _submitVote(
            SubmitVoteParam(
                _voter,
                castVoteTime,
                proposalId,
                voteParam,
                _votes,
                messagingOptions,
                // If lzReceive fails due to insufficient native fees, user can retry by sending more native fees(msg.value)
                messagingNativeFee + msg.value,
                _voter
            )
        );
    }

    /**
     * @dev Internal function to handle the vote fee.
     * @param _voter The address of the voter.
     * @param _voteParam The parameters of the vote.
     * @param _optionsParam The options for the vote.
     * @param _fee The fee for the vote.
     * @return The handled vote fee.
     */
    function _handleVoteFee(
        address _voter,
        VoteParam memory _voteParam,
        OptionsParam memory _optionsParam,
        VoteFee memory _fee
    ) internal virtual returns (VoteFee memory) {
        uint256 expectedNativeFee = _fee.readNativeFee + _fee.messagingNativeFee;
        if (msg.value != expectedNativeFee) {
            revert NativeFeeNotMatch(msg.value, expectedNativeFee);
        }

        MessagingFee memory expectedMessagingFee = _quoteSubmitVote(
            _voter,
            _voteParam,
            0,
            _optionsParam.messagingOptions
        );
        if (_fee.messagingNativeFee < expectedMessagingFee.nativeFee) {
            revert InsufficientMessagingFee(_fee.messagingNativeFee, expectedMessagingFee.nativeFee);
        }

        return _fee;
    }

    /**
     * @dev Internal function to submit a vote.
     * @param _param The parameters for submitting the vote.
     * @return receipt The messaging receipt.
     */
    function _submitVote(SubmitVoteParam memory _param) internal virtual returns (MessagingReceipt memory receipt) {
        bytes memory message = _encodeMessage(
            MsgData({
                proposalId: _param.proposalId,
                voter: _param.voter,
                castVoteTime: _param.castVoteTime,
                support: _param.voteParam.support,
                reason: _param.voteParam.reason,
                params: _param.voteParam.params,
                snapshot: _param.voteParam.snapshot,
                votes: _param.votes
            })
        );
        return
            // pay in lzToken is not allowed, as it cannot retry if lzReceive fails due to insufficient lzToken fees.
            endpoint.send{ value: _param.messagingNativeFee }(
                MessagingParams(mainEid, _getPeerOrRevert(mainEid), message, _param.messagingOptions, false),
                _param.refundAddress
            );
    }

    // =============================== Internal Utils ===============================

    /**
     * @dev Internal function to combine two sets of options.
     * @param _option1 The first set of options.
     * @param _option2 The second set of options.
     * @return The combined options.
     */
    function _combineOptions(
        bytes memory _option1,
        bytes memory _option2
    ) internal pure virtual returns (bytes memory) {
        if (_option1.length == 0) return _option2;
        if (_option2.length == 0) return _option1;
        if (_option1.length < 2 || _option2.length < 2)
            revert InvalidOptions(_option1.length < 2 ? _option1 : _option2);
        _assertOptionsType3(_option1);
        _assertOptionsType3(_option2);
        return bytes.concat(_option1, _option2.slice(2, _option2.length - 2));
    }

    /**
     * @dev Internal function to encode the voting context.
     * @param _castVoteTime The time the vote was cast.
     * @param _proposalId The ID of the proposal.
     * @param _voteParam The parameters of the vote.
     * @param _messagingOptions The messaging options.
     * @param _messagingNativeFee The native fee for messaging.
     * @return The encoded voting context.
     */
    function _encodeVotingContext(
        uint64 _castVoteTime,
        uint256 _proposalId,
        VoteParam memory _voteParam,
        bytes memory _messagingOptions,
        uint256 _messagingNativeFee
    ) internal view virtual returns (bytes memory) {
        return abi.encode(_castVoteTime, _proposalId, _voteParam, _messagingOptions, _messagingNativeFee);
    }

    /**
     * @dev Internal function to decode the voting context.
     * @param _context The encoded voting context.
     * @return The decoded voting context.
     */
    function _decodeVotingContext(
        bytes memory _context
    ) internal pure virtual returns (uint64, uint256, VoteParam memory, bytes memory, uint256) {
        return abi.decode(_context, (uint64, uint256, VoteParam, bytes, uint256));
    }

    /**
     * @dev Internal function to encode a cross chain message.
     * @param _msgData The message data.
     * @return The encoded message.
     */
    function _encodeMessage(MsgData memory _msgData) internal pure virtual returns (bytes memory) {
        return abi.encode(_msgData);
    }
}
// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

/**
 * @dev Struct representing the parameters for a vote.
 * @param support The support value for the vote.
 * @param reason The reason for the vote.
 * @param params Additional parameters for the vote.
 * @param proposalId The ID of the proposal being voted on.
 * @param snapshot The snapshot for the vote.
 */
struct VoteParam {
    uint8 support;
    string reason;
    bytes params;
    uint256 proposalId;
    uint64 snapshot;
}

/**
 * @dev Struct representing the fees for a vote.
 * @param readNativeFee The native fee for reading.
 * @param readLzTokenFee The LayerZero token fee for reading.
 * @param messagingNativeFee The native fee for messaging.
 */
struct VoteFee {
    uint256 readNativeFee;
    uint256 readLzTokenFee;
    uint256 messagingNativeFee;
}

/**
 * @dev Struct representing the options for a vote.
 * @param readOptions The options for reading.
 * @param messagingOptions The options for messaging.
 */
struct OptionsParam {
    bytes readOptions;
    bytes messagingOptions;
}

/**
 * @title IGovernorOVoteSide
 * @dev Interface for the Governor OVote side contract.
 */
interface IGovernorOVoteSide {
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
    ) external view returns (VoteFee memory fee);

    /**
     * @notice Casts a vote.
     * @param _voteParam The parameters of the vote.
     * @param _options The options for the vote.
     * @param _fee The fee for the vote.
     */
    function lzCastVote(
        VoteParam calldata _voteParam,
        OptionsParam calldata _options,
        VoteFee calldata _fee
    ) external payable;
}
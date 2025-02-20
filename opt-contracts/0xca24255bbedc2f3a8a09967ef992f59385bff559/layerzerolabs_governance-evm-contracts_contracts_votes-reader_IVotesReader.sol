// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.20;

import { MessagingFee, MessagingReceipt } from "./layerzerolabs_lz-evm-protocol-v2_contracts_interfaces_ILayerZeroEndpointV2.sol";

/**
 * @title IVotesReadCallback
 * @dev Interface for the callback function to handle received votes.
 */
interface IVotesReadCallback {
    /**
     * @notice Called when votes are received.
     * @param _voter The address of the voter.
     * @param _snapshot The snapshot timestamp/block number.
     * @param _votes The number of votes received.
     * @param _extraData Additional data.
     */
    function onVotesReceived(
        address _voter,
        uint64 _snapshot,
        uint256 _votes,
        bytes calldata _extraData
    ) external payable;
}

/**
 * @title IVotesReader
 * @dev Interface for reading votes and quoting the fee for reading votes.
 */
interface IVotesReader {
    /**
     * @notice Quotes the fee required to read votes.
     * @param _voter The address of the voter.
     * @param _snapshot The snapshot block number.
     * @param _extraData Additional data.
     * @param _options Additional options for the read operation.
     * @param _payInLzToken A boolean indicating whether to pay in LzToken.
     * @return The calculated messaging fee.
     */
    function quote(
        address _voter,
        uint64 _snapshot,
        bytes calldata _extraData,
        bytes calldata _options,
        bool _payInLzToken
    ) external view returns (MessagingFee memory);

    /**
     * @notice Reads votes and sends a read request.
     * @param _voter The address of the voter.
     * @param _snapshot The snapshot block number.
     * @param _extraData Additional data.
     * @param _options Additional options for the read operation.
     * @param _fee The fee for the read operation.
     * @param _refundAddress The address to refund any excess fee.
     * @return The messaging receipt.
     */
    function readVotes(
        address _voter,
        uint64 _snapshot,
        bytes calldata _extraData,
        bytes calldata _options,
        MessagingFee calldata _fee,
        address _refundAddress
    ) external payable returns (MessagingReceipt memory);
}
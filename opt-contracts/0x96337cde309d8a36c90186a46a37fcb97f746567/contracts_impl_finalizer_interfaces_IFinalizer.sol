// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import { MessagingFee, MessagingReceipt } from "./layerzerolabs_lz-evm-protocol-v2_contracts_interfaces_ILayerZeroEndpointV2.sol";

/**
 * @title IVoteSendSide
 * @dev Interface for the vote sending side of the finalizer contract.
 */
interface IVoteSendSide {
    /**
     * @notice Gets the count of votes sent for a given proposal.
     * @param _proposalId The ID of the proposal.
     * @return The count of votes sent.
     */
    function castVoteSentCount(uint256 _proposalId) external view returns (uint256);
}

/**
 * @title IFinalizer
 * @dev Interface for the finalizer contract.
 */
interface IFinalizer {
    /**
     * @notice Quotes the fee required to finalize a proposal.
     * @param _proposalId The ID of the proposal.
     * @param _options The options for the read operation.
     * @param _payInLzToken A boolean indicating whether to pay in LzToken.
     * @return The calculated messaging fee.
     */
    function quote(
        uint256 _proposalId,
        bytes calldata _options,
        bool _payInLzToken
    ) external view returns (MessagingFee memory);

    /**
     * @notice Finalizes a proposal by sending a read request to multiple chains.
     * @param _proposalId The ID of the proposal.
     * @param _options The options for the read operation.
     * @param _lzTokenFee The fee to be paid in LzToken.
     * @param _refundAddress The address to refund any excess fee.
     * @return The messaging receipt.
     */
    function finalize(
        uint256 _proposalId,
        bytes calldata _options,
        uint256 _lzTokenFee,
        address _refundAddress
    ) external payable returns (MessagingReceipt memory);
}
// SPDX-License-Identifier: AGPL-3.0-only

pragma solidity 0.8.22;

import { IAssetDataStructures } from './contracts_interfaces_IAssetDataStructures.sol';

/**
 * @title IGatewayClient
 * @notice Cross-chain gateway client interface
 */
interface IGatewayClient is IAssetDataStructures {
    /**
     * @notice Cross-chain message handler on the target chain
     * @dev The function is called by cross-chain gateways
     * @param _messageSourceChainId The ID of the message source chain
     * @param _payloadData The content of the cross-chain message
     * @param _assetAddress The asset address
     * @param _assetAmount The asset amount
     */
    function handleExecutionPayload(
        uint256 _messageSourceChainId,
        bytes calldata _payloadData,
        address _assetAddress,
        uint256 _assetAmount
    ) external payable;

    /**
     * @notice The standard "receive" function
     */
    receive() external payable;
}
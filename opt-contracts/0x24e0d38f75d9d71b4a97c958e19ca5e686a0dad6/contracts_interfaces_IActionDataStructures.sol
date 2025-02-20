// SPDX-License-Identifier: AGPL-3.0-only

pragma solidity 0.8.22;

import { IAssetDataStructures } from './contracts_interfaces_IAssetDataStructures.sol';

/**
 * @title IActionDataStructures
 * @notice Action data structure declarations
 */
interface IActionDataStructures is IAssetDataStructures {
    /**
     * @notice Cross-chain action data structure
     * @param gatewayType The numeric type of the cross-chain gateway
     * @param assetType The numeric type of the asset
     * @param sourceTokenAddress The address of the input token on the source chain
     * @param sourceSwapInfo The data for the source chain swap
     * @param targetChainId The action target chain ID
     * @param targetTokenAddress The address of the output token on the destination chain
     * @param targetSwapInfo The data for the target chain swap
     * @param targetRecipient The address of the recipient on the target chain
     * @param targetGasReserveOverride The target gas reserve override value
     * @param gatewaySettings The gateway-specific settings data
     */
    struct Action {
        uint256 gatewayType;
        uint256 assetType;
        address sourceTokenAddress;
        SwapInfo sourceSwapInfo;
        uint256 targetChainId;
        address targetTokenAddress;
        SwapInfo targetSwapInfo;
        address targetRecipient;
        uint256 targetGasReserveOverride;
        bytes gatewaySettings;
    }

    /**
     * @notice Token swap data structure
     * @param fromAmount The quantity of the token
     * @param routerType The numeric type of the swap router
     * @param routerData The data for the swap router call
     */
    struct SwapInfo {
        uint256 fromAmount;
        uint256 routerType;
        bytes routerData;
    }

    /**
     * @notice Cross-chain message data structure
     * @param actionId The unique identifier of the cross-chain action
     * @param sourceSender The address of the sender on the source chain
     * @param assetType The numeric type of the asset
     * @param targetTokenAddress The address of the output token on the target chain
     * @param targetSwapInfo The data for the target chain swap
     * @param targetRecipient The address of the recipient on the target chain
     * @param targetGasReserveOverride The target gas reserve override value
     */
    struct TargetMessage {
        uint256 actionId;
        address sourceSender;
        uint256 assetType;
        address targetTokenAddress;
        SwapInfo targetSwapInfo;
        address targetRecipient;
        uint256 targetGasReserveOverride;
    }
}
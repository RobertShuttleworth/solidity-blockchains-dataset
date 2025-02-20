// SPDX-License-Identifier: AGPL-3.0-only

pragma solidity 0.8.22;

import { IAssetDataStructures } from './contracts_interfaces_IAssetDataStructures.sol';

/**
 * @title IGateway
 * @notice Cross-chain gateway interface
 */
interface IGateway is IAssetDataStructures {
    /**
     * @notice Send a cross-chain message
     * @param _targetChainId The message target chain ID
     * @param _appMessage The app message content
     * @param _settings The gateway-specific settings
     * @param _assetAmountData The asset amount data
     */
    function sendMessage(
        uint256 _targetChainId,
        bytes calldata _appMessage,
        bytes calldata _settings,
        AssetAmountData calldata _assetAmountData
    ) external payable;

    /**
     * @notice Cross-chain message fee estimation (native token fee only)
     * @param _targetChainId The ID of the target chain
     * @param _appMessage The app message content
     * @param _settings The gateway-specific settings
     * @param _assetAmountData The asset amount data
     * @return nativeFee Message fee (native token)
     */
    function messageFee(
        uint256 _targetChainId,
        bytes calldata _appMessage,
        bytes calldata _settings,
        AssetAmountData calldata _assetAmountData
    ) external view returns (uint256 nativeFee);

    /**
     * @notice Target chain amount estimation
     * @param _targetChainId The ID of the target chain
     * @param _appMessage The app message content
     * @param _settings The gateway-specific settings
     * @param _assetAmountData The asset amount data
     * @return amount Target chain amount
     */
    function targetAmount(
        uint256 _targetChainId,
        bytes calldata _appMessage,
        bytes calldata _settings,
        AssetAmountData calldata _assetAmountData
    ) external view returns (uint256 amount);

    /**
     * @notice Asset address by type
     * @param _assetType The asset type
     * @return The asset address
     */
    function assetByType(uint256 _assetType) external view returns (address);
}
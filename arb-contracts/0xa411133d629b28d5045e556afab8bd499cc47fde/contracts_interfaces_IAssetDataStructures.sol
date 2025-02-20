// SPDX-License-Identifier: AGPL-3.0-only

pragma solidity 0.8.22;

/**
 * @title IAssetDataStructures
 * @notice Token data structure declarations
 */
interface IAssetDataStructures {
    /**
     * @notice Asset amount data structure
     * @param assetType The type of the asset
     * @param amount The amount of the asset
     */
    struct AssetAmountData {
        uint256 assetType;
        uint256 amount;
    }
}
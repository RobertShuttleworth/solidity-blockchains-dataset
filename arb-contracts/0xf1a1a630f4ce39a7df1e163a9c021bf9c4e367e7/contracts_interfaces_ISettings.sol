// SPDX-License-Identifier: AGPL-3.0-only

pragma solidity 0.8.22;

/**
 * @title ISettings
 * @notice Settings data structure declarations
 */
interface ISettings {
    /**
     * @notice Source chain settings for a cross-chain swap
     * @param gateway The cross-chain gateway contract address
     * @param router The swap router contract address
     * @param routerTransfer The swap router transfer contract address
     */
    struct SourceSettings {
        address gateway;
        address router;
        address routerTransfer;
    }

    /**
     * @notice Target chain settings for a cross-chain swap
     * @param router The swap router contract address
     * @param routerTransfer The swap router transfer contract address
     * @param gasReserve The target chain gas reserve value
     */
    struct TargetSettings {
        address router;
        address routerTransfer;
        uint256 gasReserve;
    }
}
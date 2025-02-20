// SPDX-License-Identifier: SEE LICENSE IN LICENSE
pragma solidity ^0.8.25;

interface ICore {
    struct VaultConfig {
        // Required fields
        address asset;
        uint8 decimals;
        address operator;
        string name;
        string symbol;
        bytes extraData;
    }

    /* ========== MUTATIVE FUNCTIONS ==========*/
    function deployVaults(VaultConfig[] calldata vaultConfigs, address implementation)
        external
        returns (address[] memory vaults);
    function allowlistAssets(address[] calldata assets, address[] calldata slashingHandlers) external;
    /* ============ VIEW FUNCTIONS ============ */
    function implementation(address vault) external view returns (address);
    function owner() external returns (address);
    /* ======================================== */
}
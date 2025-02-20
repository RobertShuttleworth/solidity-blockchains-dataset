// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import "./pythnetwork_pyth-sdk-solidity_IPyth.sol";
import "./src_interfaces_IHub.sol";
import "./src_interfaces_IAssetRegistry.sol";
import "./src_interfaces_ISynonymPriceOracle.sol";
import "./src_contracts_HubSpokeStructs.sol";

interface IHubPriceUtilities {
    function getAssetRegistry() external view returns (IAssetRegistry);
    function getPrices(address assetAddress) external view returns (uint256, uint256, uint256, uint256);
    function getVaultEffectiveNotionals(address vaultOwner, bool collateralizationRatios) external view returns (HubSpokeStructs.NotionalVaultAmount memory);
    function calculateNotionals(address asset, HubSpokeStructs.DenormalizedVaultAmount memory vaultAmount) external view returns (HubSpokeStructs.NotionalVaultAmount memory);
    function calculateEffectiveNotionals(address asset, HubSpokeStructs.DenormalizedVaultAmount memory vaultAmount) external view returns (HubSpokeStructs.NotionalVaultAmount memory);
    function invertNotionals(address asset, HubSpokeStructs.NotionalVaultAmount memory realValues) external view returns (HubSpokeStructs.DenormalizedVaultAmount memory);
    function applyCollateralizationRatios(address asset, HubSpokeStructs.NotionalVaultAmount memory vaultAmount) external view returns (HubSpokeStructs.NotionalVaultAmount memory);
    function removeCollateralizationRatios(address asset, HubSpokeStructs.NotionalVaultAmount memory vaultAmount) external view returns (HubSpokeStructs.NotionalVaultAmount memory);
    function getHub() external view returns (IHub);
    function setHub(IHub _hub) external;
    function getPriceOracle() external view returns (ISynonymPriceOracle);
    function setPriceOracle(ISynonymPriceOracle _priceOracle) external;
    function getPriceStandardDeviations() external view returns (uint256, uint256);
    function setPriceStandardDeviations(uint256 _priceStandardDeviations, uint256 _precision) external;
}
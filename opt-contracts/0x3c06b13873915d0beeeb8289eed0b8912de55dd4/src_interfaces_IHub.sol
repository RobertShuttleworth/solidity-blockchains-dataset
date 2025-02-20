// SPDX-License-Identifier: Apache 2

pragma solidity ^0.8.0;

import "./src_contracts_HubSpokeStructs.sol";
import "./src_interfaces_ILiquidationCalculator.sol";
import "./src_interfaces_IHubPriceUtilities.sol";
import "./src_interfaces_IAssetRegistry.sol";
import {IWormholeTunnel} from "./src_interfaces_IWormholeTunnel.sol";

/**
 * @notice interface for external contracts that need to access Hub state
 */
interface IHub {
    function checkVaultHasAssets(address vault, address assetAddress, uint256 normalizedAmount)
        external
        view;

    function checkProtocolGloballyHasAssets(
        address assetAddress,
        uint256 normalizedAmount
    ) external view;

    function checkProtocolGloballyHasAssets(
        address assetAddress,
        uint256 normalizedAmount,
        uint256 borrowLimit
    ) external view;

    function getInterestAccrualIndices(address assetAddress)
        external
        view
        returns (HubSpokeStructs.AccrualIndices memory);

    function getInterestAccrualIndexPrecision() external view returns (uint256);

    function getVaultAmounts(address vaultOwner, address assetAddress)
        external
        view
        returns (HubSpokeStructs.DenormalizedVaultAmount memory);

    function getCurrentAccrualIndices(address assetAddress)
        external
        view
        returns (HubSpokeStructs.AccrualIndices memory);

    function updateAccrualIndices(address assetAddress) external;

    function getLastActivityBlockTimestamp(address assetAddress) external view returns (uint256);

    function getGlobalAmounts(address assetAddress) external view returns (HubSpokeStructs.DenormalizedVaultAmount memory);

    function getReserveAmount(address assetAddress) external view returns (uint256);

    function getSpokeBalances(uint16 chainId, bytes32 homeAddress) external view returns (HubSpokeStructs.HubSpokeBalances memory);

    function getSpokeBalances(address wrappedTokenAddress) external view returns (HubSpokeStructs.HubSpokeBalances memory);

    function getLiquidationCalculator() external view returns (ILiquidationCalculator);

    function getPriceUtilities() external view returns (IHubPriceUtilities);

    function getAssetRegistry() external view returns (IAssetRegistry);

    function getLiquidationFeeAndPrecision() external view returns (uint256, uint256);

    function liquidation(ILiquidationCalculator.LiquidationInput memory input) external;

    function userActions(HubSpokeStructs.Action action, address asset, uint256 amount) external payable;

    function userActionMessage(
        IWormholeTunnel.MessageSource calldata source,
        IERC20 token,
        uint256 amount,
        bytes calldata payload
    ) external payable;

    function instantActionMessage(
        IWormholeTunnel.MessageSource calldata source,
        IERC20 token,
        uint256 amount,
        bytes calldata payload
    ) external;

    function finalizeCreditMessage(
        IWormholeTunnel.MessageSource calldata source,
        IERC20 token,
        uint256 amount,
        bytes calldata payload
    ) external;

    function confirmTopUpMessage(
        IWormholeTunnel.MessageSource calldata source,
        IERC20 token,
        uint256 amount,
        bytes calldata payload
    ) external;

    function confirmFixLostCreditMessage(
        IWormholeTunnel.MessageSource calldata source,
        IERC20 token,
        uint256 amount,
        bytes calldata payload
    ) external;
}
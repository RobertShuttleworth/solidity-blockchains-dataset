// SPDX-License-Identifier: AGPL-3.0-only

pragma solidity 0.8.22;

import { ISettings } from './contracts_interfaces_ISettings.sol';

interface IRegistry is ISettings {
    /**
     * @notice Getter of the registered gateway flag by the account address
     * @param _account The account address
     * @return The registered gateway flag
     */
    function isGatewayAddress(address _account) external view returns (bool);

    /**
     * @notice Getter of source chain settings for a cross-chain swap
     * @param _gatewayType The type of the cross-chain gateway
     * @param _routerType The type of the swap router
     * @return Source chain settings for a cross-chain swap
     */
    function sourceSettings(
        uint256 _gatewayType,
        uint256 _routerType
    ) external view returns (SourceSettings memory);

    /**
     * @notice Getter of target chain settings for a cross-chain swap
     * @param _routerType The type of the swap router
     * @return Target chain settings for a cross-chain swap
     */
    function targetSettings(uint256 _routerType) external view returns (TargetSettings memory);
}
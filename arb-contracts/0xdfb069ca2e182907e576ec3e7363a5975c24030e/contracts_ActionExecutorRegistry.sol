// SPDX-License-Identifier: AGPL-3.0-only

pragma solidity 0.8.22;

import { IRegistry } from './contracts_interfaces_IRegistry.sol';
import { BalanceManagement } from './contracts_BalanceManagement.sol';
import { SystemVersionId } from './contracts_SystemVersionId.sol';
import { TargetGasReserve } from './contracts_crosschain_TargetGasReserve.sol';
import './helpers/AddressHelper.sol' as AddressHelper;
import './Constants.sol' as Constants;
import './DataStructures.sol' as DataStructures;

/**
 * @title ActionExecutorRegistry
 * @notice The contract for action settings
 */
contract ActionExecutorRegistry is SystemVersionId, TargetGasReserve, BalanceManagement, IRegistry {
    /**
     * @dev Registered cross-chain gateway addresses by type
     */
    mapping(uint256 /*gatewayType*/ => address /*gatewayAddress*/) public gatewayMap;

    /**
     * @dev Registered cross-chain gateway types
     */
    uint256[] public gatewayTypeList;

    /**
     * @dev Registered cross-chain gateway type indices
     */
    mapping(uint256 /*gatewayType*/ => DataStructures.OptionalValue /*gatewayTypeIndex*/)
        public gatewayTypeIndexMap;

    /**
     * @dev Registered cross-chain gateway flags by address
     */
    mapping(address /*account*/ => bool /*isGateway*/) public isGatewayAddress;

    /**
     * @dev Registered swap router addresses by type
     */
    mapping(uint256 /*routerType*/ => address /*routerAddress*/) public routerMap;

    /**
     * @dev Registered swap router types
     */
    uint256[] public routerTypeList;

    /**
     * @dev Registered swap router type indices
     */
    mapping(uint256 /*routerType*/ => DataStructures.OptionalValue /*routerTypeIndex*/)
        public routerTypeIndexMap;

    /**
     * @dev Registered swap router transfer addresses by router type
     */
    mapping(uint256 /*routerType*/ => address /*routerTransferAddress*/) public routerTransferMap;

    /**
     * @notice Emitted when a registered cross-chain gateway contract address is added or updated
     * @param gatewayType The type of the registered cross-chain gateway
     * @param gatewayAddress The address of the registered cross-chain gateway contract
     */
    event SetGateway(uint256 indexed gatewayType, address indexed gatewayAddress);

    /**
     * @notice Emitted when a registered cross-chain gateway contract address is removed
     * @param gatewayType The type of the removed cross-chain gateway
     */
    event RemoveGateway(uint256 indexed gatewayType);

    /**
     * @notice Emitted when a registered swap router contract address is added or updated
     * @param routerType The type of the registered swap router
     * @param routerAddress The address of the registered swap router contract
     */
    event SetRouter(uint256 indexed routerType, address indexed routerAddress);

    /**
     * @notice Emitted when a registered swap router contract address is removed
     * @param routerType The type of the removed swap router
     */
    event RemoveRouter(uint256 indexed routerType);

    /**
     * @notice Emitted when a registered swap router transfer contract address is set
     * @param routerType The type of the swap router
     * @param routerTransfer The address of the swap router transfer contract
     */
    event SetRouterTransfer(uint256 indexed routerType, address indexed routerTransfer);

    /**
     * @notice Emitted when the specified cross-chain gateway address is duplicate
     */
    error DuplicateGatewayAddressError();

    /**
     * @notice Emitted when the requested cross-chain gateway type is not set
     */
    error GatewayNotSetError();

    /**
     * @notice Emitted when the requested swap router type is not set
     */
    error RouterNotSetError();

    /**
     * @notice Deploys the ActionExecutorRegistry contract
     * @param _gateways Initial values of cross-chain gateway types and addresses
     * @param _targetGasReserve The initial gas reserve value for target chain action processing
     * @param _owner The address of the initial owner of the contract
     * @param _managers The addresses of initial managers of the contract
     * @param _addOwnerToManagers The flag to optionally add the owner to the list of managers
     */
    constructor(
        DataStructures.KeyToAddressValue[] memory _gateways,
        uint256 _targetGasReserve,
        address _owner,
        address[] memory _managers,
        bool _addOwnerToManagers
    ) {
        for (uint256 index; index < _gateways.length; index++) {
            DataStructures.KeyToAddressValue memory item = _gateways[index];

            _setGateway(item.key, item.value);
        }

        _setTargetGasReserve(_targetGasReserve);

        _initRoles(_owner, _managers, _addOwnerToManagers);
    }

    /**
     * @notice Adds or updates a registered cross-chain gateway contract address
     * @param _gatewayType The type of the registered cross-chain gateway
     * @param _gatewayAddress The address of the registered cross-chain gateway contract
     */
    function setGateway(uint256 _gatewayType, address _gatewayAddress) external onlyManager {
        _setGateway(_gatewayType, _gatewayAddress);
    }

    /**
     * @notice Removes a registered cross-chain gateway contract address
     * @param _gatewayType The type of the removed cross-chain gateway
     */
    function removeGateway(uint256 _gatewayType) external onlyManager {
        address gatewayAddress = gatewayMap[_gatewayType];

        if (gatewayAddress == address(0)) {
            revert GatewayNotSetError();
        }

        DataStructures.combinedMapRemove(
            gatewayMap,
            gatewayTypeList,
            gatewayTypeIndexMap,
            _gatewayType
        );

        delete isGatewayAddress[gatewayAddress];

        emit RemoveGateway(_gatewayType);
    }

    /**
     * @notice Adds or updates registered swap router contract addresses
     * @param _routers Types and addresses of swap routers
     */
    function setRouters(DataStructures.KeyToAddressValue[] calldata _routers) external onlyManager {
        for (uint256 index; index < _routers.length; index++) {
            DataStructures.KeyToAddressValue calldata item = _routers[index];

            _setRouter(item.key, item.value);
        }
    }

    /**
     * @notice Removes registered swap router contract addresses
     * @param _routerTypes Types of swap routers
     */
    function removeRouters(uint256[] calldata _routerTypes) external onlyManager {
        for (uint256 index; index < _routerTypes.length; index++) {
            uint256 routerType = _routerTypes[index];

            _removeRouter(routerType);
        }
    }

    /**
     * @notice Adds or updates a registered swap router transfer contract address
     * @dev Zero address can be used to remove a router transfer contract
     * @param _routerType The type of the swap router
     * @param _routerTransfer The address of the swap router transfer contract
     */
    function setRouterTransfer(uint256 _routerType, address _routerTransfer) external onlyManager {
        if (routerMap[_routerType] == address(0)) {
            revert RouterNotSetError();
        }

        AddressHelper.requireContractOrZeroAddress(_routerTransfer);

        routerTransferMap[_routerType] = _routerTransfer;

        emit SetRouterTransfer(_routerType, _routerTransfer);
    }

    /**
     * @notice Getter of source chain settings for a cross-chain swap
     * @param _gatewayType The type of the cross-chain gateway
     * @param _routerType The type of the swap router
     * @return Source chain settings for a cross-chain swap
     */
    function sourceSettings(
        uint256 _gatewayType,
        uint256 _routerType
    ) external view returns (SourceSettings memory) {
        (address router, address routerTransfer) = _routerAddresses(_routerType);

        return
            SourceSettings({
                gateway: gatewayMap[_gatewayType],
                router: router,
                routerTransfer: routerTransfer
            });
    }

    /**
     * @notice Getter of target chain settings for a cross-chain swap
     * @param _routerType The type of the swap router
     * @return Target chain settings for a cross-chain swap
     */
    function targetSettings(uint256 _routerType) external view returns (TargetSettings memory) {
        (address router, address routerTransfer) = _routerAddresses(_routerType);

        return
            TargetSettings({
                router: router,
                routerTransfer: routerTransfer,
                gasReserve: targetGasReserve
            });
    }

    /**
     * @notice Getter of registered cross-chain gateway type count
     * @return Registered cross-chain gateway type count
     */
    function gatewayTypeCount() external view returns (uint256) {
        return gatewayTypeList.length;
    }

    /**
     * @notice Getter of the complete list of registered cross-chain gateway types
     * @return The complete list of registered cross-chain gateway types
     */
    function fullGatewayTypeList() external view returns (uint256[] memory) {
        return gatewayTypeList;
    }

    /**
     * @notice Getter of registered swap router type count
     * @return Registered swap router type count
     */
    function routerTypeCount() external view returns (uint256) {
        return routerTypeList.length;
    }

    /**
     * @notice Getter of the complete list of registered swap router types
     * @return The complete list of registered swap router types
     */
    function fullRouterTypeList() external view returns (uint256[] memory) {
        return routerTypeList;
    }

    function _setGateway(uint256 _gatewayType, address _gatewayAddress) private {
        address previousGatewayAddress = gatewayMap[_gatewayType];

        if (_gatewayAddress != previousGatewayAddress) {
            if (isGatewayAddress[_gatewayAddress]) {
                revert DuplicateGatewayAddressError(); // The address is set for another gateway type
            }

            AddressHelper.requireContract(_gatewayAddress);

            DataStructures.combinedMapSet(
                gatewayMap,
                gatewayTypeList,
                gatewayTypeIndexMap,
                _gatewayType,
                _gatewayAddress,
                Constants.LIST_SIZE_LIMIT_DEFAULT
            );

            if (previousGatewayAddress != address(0)) {
                delete isGatewayAddress[previousGatewayAddress];
            }

            isGatewayAddress[_gatewayAddress] = true;
        }

        emit SetGateway(_gatewayType, _gatewayAddress);
    }

    function _setRouter(uint256 _routerType, address _routerAddress) private {
        AddressHelper.requireContract(_routerAddress);

        DataStructures.combinedMapSet(
            routerMap,
            routerTypeList,
            routerTypeIndexMap,
            _routerType,
            _routerAddress,
            Constants.LIST_SIZE_LIMIT_ROUTERS
        );

        emit SetRouter(_routerType, _routerAddress);
    }

    function _removeRouter(uint256 _routerType) private {
        DataStructures.combinedMapRemove(
            routerMap,
            routerTypeList,
            routerTypeIndexMap,
            _routerType
        );

        delete routerTransferMap[_routerType];

        emit RemoveRouter(_routerType);
    }

    function _routerAddresses(
        uint256 _routerType
    ) private view returns (address router, address routerTransfer) {
        router = routerMap[_routerType];
        routerTransfer = routerTransferMap[_routerType];

        if (routerTransfer == address(0)) {
            routerTransfer = router;
        }
    }
}
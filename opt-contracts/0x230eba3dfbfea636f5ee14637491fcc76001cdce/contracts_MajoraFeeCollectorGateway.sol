// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.20;

import "./openzeppelin_contracts-upgradeable_access_manager_AccessManagedUpgradeable.sol";
import "./openzeppelin_contracts-upgradeable_proxy_utils_Initializable.sol";
import "./openzeppelin_contracts_token_ERC20_IERC20.sol";
import "./openzeppelin_contracts_token_ERC20_utils_SafeERC20.sol";

import "./majora-finance_portal_contracts_interfaces_IMajoraPortal.sol";
import "./majora-finance_access-manager_contracts_interfaces_IMajoraAddressesProvider.sol";

/**
 * @title Interface of Strateg Block Registry
 * @author Majora Development Association
 * @notice A contract for registering strategy blocks.
 */
contract MajoraFeeCollectorGateway is Initializable, AccessManagedUpgradeable {
    using SafeERC20 for IERC20;

    /// @notice The address provider
    IMajoraAddressesProvider public addressProvider;

    /**
     * @notice Event emitted when a portal swap is executed
     */
    event PortalSwapExecuted(
        uint8 route,
        address sourceAsset,
        address targetAsset,
        uint256 amount
    );

    /**
     * @notice Event emitted when a portal bridge is executed
     */
    event PortalBridgeExecuted( 
        uint8 route,
        address sourceAsset,
        address targetAsset,
        uint256 amount,
        uint256 targetChain
    );

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    receive() external payable {}

    fallback() external payable {}

    /**
     * @notice Initialize the contract
     * @param _authority The address of the authority
     * @param _addressProvider The address provider
     */
    function initialize (
        address _authority,
        address _addressProvider
    ) initializer public {
        __AccessManaged_init(_authority);
        addressProvider = IMajoraAddressesProvider(_addressProvider); 
    }

    /**
     * @notice Transfer tokens
     */
    function transfer(
        address _receiver,
        address[] memory _assets,
        uint256[] memory _amounts
    ) external restricted {
        for (uint i = 0; i < _assets.length; i++) {
            IERC20(_assets[i]).safeTransfer(_receiver, _amounts[i]);
        }
    }

    /**
     * @notice Execute a portal swap
     */
    function portalSwap(
        uint8 _route,
        address _approvalAddress,
        address _sourceAsset,
        address _targetAsset,
        uint256 _amount,
        bytes calldata _routeParams
    ) external restricted {
        address portal = addressProvider.portal();
        IERC20 source = IERC20(_sourceAsset);
        
        source.safeIncreaseAllowance(portal, _amount);
        IMajoraPortal(portal).majoraBlockSwap(
            _route,
            _approvalAddress,
            _sourceAsset,
            _targetAsset,
            _amount,
            _routeParams
        );

        emit PortalSwapExecuted(
            _route,
            _sourceAsset,
            _targetAsset,
            _amount
        );
    }

    /**
     * @notice Execute a portal bridge
     */
    function portalBridge(
        uint8 _route,
        address _approvalAddress,
        address _sourceAsset,
        address _targetAsset,
        uint256 _amount,
        uint256 _targetChain,
        bytes calldata _routeParams
    ) external payable restricted {
        address portal = addressProvider.portal();
        IERC20(_sourceAsset).safeIncreaseAllowance(portal, _amount);
        IMajoraPortal(portal).swapAndBridge{value: msg.value}(
            false,
            _route,
            _approvalAddress,
            _sourceAsset,
            _targetAsset,
            _amount,
            _targetChain,
            "", 
            _routeParams
        );

        emit PortalBridgeExecuted(
            _route,
            _sourceAsset,
            _targetAsset,
            _amount,
            _targetChain
        );
    }
}
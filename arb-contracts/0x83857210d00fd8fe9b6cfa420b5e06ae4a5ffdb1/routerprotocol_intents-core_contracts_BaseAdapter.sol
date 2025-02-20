// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

import {Basic} from "./routerprotocol_intents-core_contracts_common_Basic.sol";
import {Errors} from "./routerprotocol_intents-core_contracts_utils_Errors.sol";
import {ReentrancyGuard} from "./routerprotocol_intents-core_contracts_utils_ReentrancyGuard.sol";
import {AdapterDataProvider} from "./routerprotocol_intents-core_contracts_AdapterDataProvider.sol";

/**
 * @title BaseAdapter
 * @author Router Protocol
 * @notice This contract is the base implementation of an intent adapter based on Router
 * Cross-Chain Intent Framework.
 */
abstract contract BaseAdapter is Basic, ReentrancyGuard {
    address private immutable _self;
    address private immutable _native;
    address private immutable _wnative;
    AdapterDataProvider private immutable _adapterDataProvider;

    event ExecutionEvent(string indexed adapterName, bytes data);
    event OperationFailedRefundEvent(
        address token,
        address recipient,
        uint256 amount
    );
    event UnsupportedOperation(
        address token,
        address refundAddress,
        uint256 amount
    );

    constructor(
        address __native,
        address __wnative,
        bool __deployDataProvider,
        address __owner
    ) {
        _self = address(this);
        _native = __native;
        _wnative = __wnative;

        AdapterDataProvider dataProvider;

        if (__deployDataProvider)
            dataProvider = new AdapterDataProvider(__owner);
        else dataProvider = AdapterDataProvider(address(0));

        _adapterDataProvider = dataProvider;
    }

    /**
     * @dev function to get the address of weth
     */
    function wnative() public view override returns (address) {
        return _wnative;
    }

    /**
     * @dev function to get the address of native token
     */
    function native() public view override returns (address) {
        return _native;
    }

    /**
     * @dev function to get the AdapterDataProvider instance for this contract
     */
    function adapterDataProvider() public view returns (AdapterDataProvider) {
        return _adapterDataProvider;
    }

    /**
     * @dev Function to check whether the contract is a valid preceding contract registered in
     * the head registry.
     * @dev This registry governs the initiation of the adapter, exclusively listing authorized
     * preceding adapters.
     * @notice Only the adapters documented in this registry can invoke the current adapter,
     * thereby guaranteeing regulated and secure execution sequences.
     * @param precedingContract Address of preceding contract.
     * @return true if valid, false if invalid.
     */
    function isAuthorizedPrecedingContract(
        address precedingContract
    ) public view returns (bool) {
        return
            _adapterDataProvider.isAuthorizedPrecedingContract(
                precedingContract
            );
    }

    /**
     * @dev Function to check whether the contract is a valid succeeding contract registered in
     * the tail registry.
     * @dev This registry dictates the potential succeeding actions by listing adapters that
     * may be invoked following the current one.
     * @notice Only the adapters documented in this registry can be invoked by the current adapter,
     * thereby guaranteeing regulated and secure execution sequences.
     * @param succeedingContract Address of succeeding contract.
     * @return true if valid, false if invalid.
     */
    function isAuthorizedSucceedingContract(
        address succeedingContract
    ) public view returns (bool) {
        return
            _adapterDataProvider.isAuthorizedSucceedingContract(
                succeedingContract
            );
    }

    /**
     * @dev Function to check whether the asset is a valid inbound asset registered in the inbound
     * asset registry.
     * @dev This registry keeps track of all the acceptable incoming assets, ensuring that the
     * adapter only processes predefined asset types.
     * @param asset Address of the asset.
     * @return true if valid, false if invalid.
     */
    function isValidInboundAsset(address asset) public view returns (bool) {
        return _adapterDataProvider.isValidInboundAsset(asset);
    }

    /**
     * @dev Function to check whether the asset is a valid outbound asset registered in the outbound
     * asset registry.
     * @dev It manages the types of assets that the adapter is allowed to output, thus controlling
     * the flow’s output and maintaining consistency.
     * @param asset Address of the asset.
     * @return true if valid, false if invalid.
     */
    function isValidOutboundAsset(address asset) public view returns (bool) {
        return _adapterDataProvider.isValidOutboundAsset(asset);
    }

    /**
     * @dev function to get the name of the adapter
     */
    function name() public view virtual returns (string memory);

    /**
     * @dev function to get the address of the contract
     */
    function self() public view returns (address) {
        return _self;
    }
}
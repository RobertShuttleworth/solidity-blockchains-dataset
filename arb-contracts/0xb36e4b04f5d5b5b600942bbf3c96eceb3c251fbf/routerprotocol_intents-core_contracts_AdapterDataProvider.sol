// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

import {IAdapterDataProvider} from "./routerprotocol_intents-core_contracts_interfaces_IAdapterDataProvider.sol";

/**
 * @title AdapterDataProvider
 * @author Router Protocol
 * @notice This contract serves as the data provider for an intent adapter based on Router
 * Cross-Chain Intent Framework.
 */
contract AdapterDataProvider is IAdapterDataProvider {
    address private _owner;
    mapping(address => bool) private _headRegistry;
    mapping(address => bool) private _tailRegistry;
    mapping(address => bool) private _inboundAssetRegistry;
    mapping(address => bool) private _outboundAssetRegistry;

    constructor(address __owner) {
        _owner = __owner;
    }

    /**
     * @inheritdoc IAdapterDataProvider
     */
    function owner() external view returns (address) {
        return _owner;
    }

    /**
     * @inheritdoc IAdapterDataProvider
     */
    function setOwner(address __owner) external onlyOwner {
        _owner = __owner;
    }

    /**
     * @inheritdoc IAdapterDataProvider
     */
    function isAuthorizedPrecedingContract(
        address precedingContract
    ) external view returns (bool) {
        if (precedingContract == address(0)) return true;
        return _headRegistry[precedingContract];
    }

    /**
     * @inheritdoc IAdapterDataProvider
     */
    function isAuthorizedSucceedingContract(
        address succeedingContract
    ) external view returns (bool) {
        if (succeedingContract == address(0)) return true;
        return _tailRegistry[succeedingContract];
    }

    /**
     * @inheritdoc IAdapterDataProvider
     */
    function isValidInboundAsset(address asset) external view returns (bool) {
        return _inboundAssetRegistry[asset];
    }

    /**
     * @inheritdoc IAdapterDataProvider
     */
    function isValidOutboundAsset(address asset) external view returns (bool) {
        return _outboundAssetRegistry[asset];
    }

    /**
     * @inheritdoc IAdapterDataProvider
     */
    function setPrecedingContract(
        address precedingContract,
        bool isValid
    ) external onlyOwner {
        _headRegistry[precedingContract] = isValid;
    }

    /**
     * @inheritdoc IAdapterDataProvider
     */
    function setSucceedingContract(
        address succeedingContract,
        bool isValid
    ) external onlyOwner {
        _tailRegistry[succeedingContract] = isValid;
    }

    /**
     * @inheritdoc IAdapterDataProvider
     */
    function setInboundAsset(address asset, bool isValid) external onlyOwner {
        _inboundAssetRegistry[asset] = isValid;
    }

    /**
     * @inheritdoc IAdapterDataProvider
     */
    function setOutboundAsset(address asset, bool isValid) external onlyOwner {
        _outboundAssetRegistry[asset] = isValid;
    }

    /**
     * @notice modifier to ensure that only owner can call this function
     */
    modifier onlyOwner() {
        _onlyOwner();
        _;
    }

    function _onlyOwner() private view {
        require(msg.sender == _owner, "Only owner");
    }
}
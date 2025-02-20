// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

/**
 * @title Interface for Adapter Data Provider contract for intent adapter.
 * @author Router Protocol.
 */

interface IAdapterDataProvider {
    /**
     * @dev Function to get the address of owner.
     */
    function owner() external view returns (address);

    /**
     * @dev Function to set the address of owner.
     * @dev This function can only be called by the owner of this contract.
     * @param __owner Address of the new owner
     */
    function setOwner(address __owner) external;

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
    ) external view returns (bool);

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
    ) external view returns (bool);

    /**
     * @dev Function to check whether the asset is a valid inbound asset registered in the inbound
     * asset registry.
     * @dev This registry keeps track of all the acceptable incoming assets, ensuring that the
     * adapter only processes predefined asset types.
     * @param asset Address of the asset.
     * @return true if valid, false if invalid.
     */
    function isValidInboundAsset(address asset) external view returns (bool);

    /**
     * @dev Function to check whether the asset is a valid outbound asset registered in the outbound
     * asset registry.
     * @dev It manages the types of assets that the adapter is allowed to output, thus controlling
     * the flow’s output and maintaining consistency.
     * @param asset Address of the asset.
     * @return true if valid, false if invalid.
     */
    function isValidOutboundAsset(address asset) external view returns (bool);

    /**
     * @dev Function to set preceding contract (head registry) for the adapter.
     * @dev This registry governs the initiation of the adapter, exclusively listing authorized
     * preceding adapters.
     * @notice Only the adapters documented in this registry can invoke the current adapter,
     * thereby guaranteeing regulated and secure execution sequences.
     * @param precedingContract Address of preceding contract.
     * @param isValid Boolean value suggesting if this is a valid preceding contract.
     */
    function setPrecedingContract(
        address precedingContract,
        bool isValid
    ) external;

    /**
     * @dev Function to set succeeding contract (tail registry) for the adapter.
     * @dev This registry dictates the potential succeeding actions by listing adapters that
     * may be invoked following the current one.
     * @notice Only the adapters documented in this registry can be invoked by the current adapter,
     * thereby guaranteeing regulated and secure execution sequences.
     * @param succeedingContract Address of succeeding contract.
     * @param isValid Boolean value suggesting if this is a valid succeeding contract.
     */
    function setSucceedingContract(
        address succeedingContract,
        bool isValid
    ) external;

    /**
     * @dev Function to set inbound asset registry for the adapter.
     * @dev This registry keeps track of all the acceptable incoming assets, ensuring that the
     * adapter only processes predefined asset types.
     * @param asset Address of the asset.
     * @param isValid Boolean value suggesting if this is a valid inbound asset.
     */
    function setInboundAsset(address asset, bool isValid) external;

    /**
     * @dev Function to set outbound asset registry for the adapter.
     * @dev It manages the types of assets that the adapter is allowed to output, thus controlling
     * the flow’s output and maintaining consistency.
     * @param asset Address of the asset.
     * @param isValid Boolean value suggesting if this is a valid inbound asset.
     */
    function setOutboundAsset(address asset, bool isValid) external;
}
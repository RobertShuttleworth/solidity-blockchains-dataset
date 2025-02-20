// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.19;

import {IWormholeRelayer} from "./contracts_modules_chain-abstraction_adapters_wormhole_interfaces_IWormholeRelayer.sol";
import {BaseAdapter} from "./contracts_modules_chain-abstraction_adapters_BaseAdapter.sol";

/// @title WormholeAdapter Adapter
/// @notice Adapter contract that integrates with the Wormhole messaging bridge to send and receive messages.
contract WormholeAdapter is BaseAdapter {
    /// @notice Error messages when quoted fee after deductions is too low
    error Adapter_FeeTooLow(uint256 requiredFee, uint256 deductedFee);

    /// @notice Event emitted when a domain ID is associated with a chain ID.
    event DomainIdAssociated(uint256 chainId, uint16 domainId);

    /// @notice Address of the Wormhole bridge on the same chain.
    /// @dev Calls to handle should only originate from this address.
    IWormholeRelayer public immutable BRIDGE;

    /// @notice The maximum gas limit the transaction will consume on destination
    uint256 public immutable GAS_LIMIT;

    /// @notice Maps Wormhole's domain ID (target id) to the corresponding chain ID.
    mapping(uint16 => uint256) public _domainIdChains;

    /// @notice Maps chain ID to the corresponding Wormhole domain ID.
    mapping(uint256 => uint16) public _chainIdDomains;

    /// @notice Constructor to initialize the WormholeAdapter.
    /// @param _bridgeRouter Address of the Wormhole bridge router on the same chain.
    /// @param name Name of the adapter.
    /// @param minimumGas Minimum gas required to relay a message.
    /// @param treasury Address of the treasury.
    /// @param fee Fee to be charged.
    /// @param chainIds Array of chain IDs supported by the adapter.
    /// @param domainIds Array of domain IDs specific to the Wormhole for the chain IDs above.
    constructor(
        address _bridgeRouter,
        string memory name,
        uint256 minimumGas,
        address treasury,
        uint48 fee,
        uint256 _gasLimit,
        uint256[] memory chainIds,
        uint16[] memory domainIds,
        address owner
    ) BaseAdapter(name, minimumGas, treasury, fee, owner) {
        if (_bridgeRouter == address(0)) revert Adapter_InvalidParams();
        GAS_LIMIT = _gasLimit;
        BRIDGE = IWormholeRelayer(_bridgeRouter);
        if (domainIds.length != chainIds.length) revert Adapter_InvalidParams();
        for (uint256 i = 0; i < domainIds.length; i++) {
            _domainIdChains[domainIds[i]] = chainIds[i];
            _chainIdDomains[chainIds[i]] = domainIds[i];
            emit DomainIdAssociated(chainIds[i], domainIds[i]);
        }
    }

    /// @notice Sends a message to Wormhole.
    /// @dev Overloaded function that accepts a RelayedMessage struct so that the Adapter can include msg.sender.
    /// @dev Gets a quote for the message and refunds any unused collects.
    /// @param destChainId The destination chain ID.
    /// @param destination The destination address.
    /// @param refundAddress The address to refund any unused gas fees.
    /// @param message The message data to be relayed.
    /// @return transferId The transfer ID of the relayed message.
    function relayMessage(
        uint256 destChainId,
        address destination,
        address refundAddress,
        bytes memory message
    ) external payable override whenNotPaused returns (bytes32 transferId) {
        // It's permissionless at this point. Msg.sender is encoded to the forwarded message
        uint16 destDomainId = _chainIdDomains[destChainId];
        if (destDomainId == 0 || trustedAdapters[destChainId] == address(0)) revert Adapter_InvalidParams(); // Bridge doesn't support this chain id

        address recipient = trustedAdapters[destChainId];
        bytes memory relayedMessage = abi.encode(BridgedMessage(message, msg.sender, destination));

        (uint256 quotedFee, ) = BRIDGE.quoteEVMDeliveryPrice(destDomainId, 0, GAS_LIMIT);
        _collectAndRefundFees(quotedFee, refundAddress);

        uint64 sequenceId = BRIDGE.sendPayloadToEvm{value: quotedFee}(destDomainId, recipient, relayedMessage, 0, GAS_LIMIT);
        transferId = bytes32(uint256(sequenceId));
    }

    /// @notice Calculates the fees required for sending a message using the Bridge's onchain quote function
    /// @notice The calculated fee includes the protocol fee if includeFee is true
    /// @param chainId The destination chain ID
    /// @param gasLimit The gasLimit with which to call the destination
    /// @param includeFee Whether to include the protocol fee in the calculation
    /// @return The calculated fee amount
    function quoteMessage(uint256 chainId, uint256 gasLimit, bool includeFee) external view returns (uint256) {
        uint16 destDomainId = _chainIdDomains[chainId];
        (uint256 fee, ) = BRIDGE.quoteEVMDeliveryPrice(destDomainId, 0, gasLimit);
        if (includeFee) {
            return fee + calculateFee(fee);
        } else {
            return fee;
        }
    }

    /// @notice Receives a message from Wormhole.
    /// @param payload The payload containing the message
    /// @param additionalMessages Additional messages to be processed, N/A
    /// @param sourceAddress The sender address on the origin chain, in bytes32 format to support non-EVM chains.
    /// @param sourceChain The domain ID of the origin chain.
    /// @param deliveryHash The delivery hash of the message.
    function receiveWormholeMessages(
        bytes memory payload,
        bytes[] memory additionalMessages,
        bytes32 sourceAddress,
        uint16 sourceChain,
        bytes32 deliveryHash
    ) external payable whenNotPaused {
        if (address(BRIDGE) != msg.sender) revert Adapter_Unauthorised();
        _registerMessage(address(uint160(uint256(sourceAddress))), deliveryHash, payload, _domainIdChains[sourceChain]);
    }

    /// @notice Sets domain IDs and corresponding chain IDs.
    /// @dev Only the owner can call this function.
    /// @param domainId Array of domain IDs.
    /// @param chainId Array of chain IDs corresponding to the domain IDs.
    function setDomainId(uint16[] memory domainId, uint256[] memory chainId) external onlyRole(DEFAULT_ADMIN_ROLE) {
        if (domainId.length != chainId.length) revert Adapter_InvalidParams();
        for (uint256 i = 0; i < domainId.length; i++) {
            _domainIdChains[domainId[i]] = chainId[i];
            _chainIdDomains[chainId[i]] = domainId[i];
            emit DomainIdAssociated(chainId[i], domainId[i]);
        }
    }

    /// @dev Internal function to collect fees and refund the difference if necessary
    /// @param quotedFee The quoted fee amount
    function _collectAndRefundFees(uint256 quotedFee, address refundAddress) internal {
        _deductFee(quotedFee);
        uint256 pFee = calculateFee(quotedFee);
        if (quotedFee + pFee > msg.value) revert Adapter_FeeTooLow(quotedFee + pFee, msg.value);
        if (quotedFee + pFee < msg.value) {
            // refund excess
            (bool success, ) = refundAddress.call{value: msg.value - quotedFee - pFee}("");
            if (!success) revert Adapter_FeeTransferFailed();
        }
    }
}
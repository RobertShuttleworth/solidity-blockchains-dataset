// SPDX-License-Identifier: MIT OR Apache-2.0
pragma solidity >=0.8.0;

/*@@@@@@@       @@@@@@@@@
 @@@@@@@@@       @@@@@@@@@
  @@@@@@@@@       @@@@@@@@@
   @@@@@@@@@       @@@@@@@@@
    @@@@@@@@@@@@@@@@@@@@@@@@@
     @@@@@  HYPERLANE  @@@@@@@
    @@@@@@@@@@@@@@@@@@@@@@@@@
   @@@@@@@@@       @@@@@@@@@
  @@@@@@@@@       @@@@@@@@@
 @@@@@@@@@       @@@@@@@@@
@@@@@@@@@       @@@@@@@@*/

// ============ Internal Imports ============
import {IPostDispatchHook} from "./contracts_interfaces_hooks_IPostDispatchHook.sol";
import {AbstractPostDispatchHook} from "./contracts_hooks_libs_AbstractPostDispatchHook.sol";
import {AbstractMessageIdAuthorizedIsm} from "./contracts_isms_hook_AbstractMessageIdAuthorizedIsm.sol";
import {TypeCasts} from "./contracts_libs_TypeCasts.sol";
import {Message} from "./contracts_libs_Message.sol";
import {StandardHookMetadata} from "./contracts_hooks_libs_StandardHookMetadata.sol";
import {MailboxClient} from "./contracts_client_MailboxClient.sol";

/**
 * @title AbstractMessageIdAuthHook
 * @notice Message hook to inform an Abstract Message ID ISM of messages published through
 * a third-party bridge.
 */
abstract contract AbstractMessageIdAuthHook is
    AbstractPostDispatchHook,
    MailboxClient
{
    using StandardHookMetadata for bytes;
    using Message for bytes;

    // ============ Constants ============

    // left-padded address for ISM to verify messages
    bytes32 public immutable ism;
    // Domain of chain on which the ISM is deployed
    uint32 public immutable destinationDomain;

    // ============ Constructor ============

    constructor(
        address _mailbox,
        uint32 _destinationDomain,
        bytes32 _ism
    ) MailboxClient(_mailbox) {
        require(_ism != bytes32(0), "AbstractMessageIdAuthHook: invalid ISM");
        require(
            _destinationDomain != 0,
            "AbstractMessageIdAuthHook: invalid destination domain"
        );
        ism = _ism;
        destinationDomain = _destinationDomain;
    }

    /// @inheritdoc IPostDispatchHook
    function hookType() external pure returns (uint8) {
        return uint8(IPostDispatchHook.Types.ID_AUTH_ISM);
    }

    // ============ Internal functions ============

    /// @inheritdoc AbstractPostDispatchHook
    function _postDispatch(
        bytes calldata metadata,
        bytes calldata message
    ) internal override {
        bytes32 id = message.id();
        require(
            _isLatestDispatched(id),
            "AbstractMessageIdAuthHook: message not latest dispatched"
        );
        require(
            message.destination() == destinationDomain,
            "AbstractMessageIdAuthHook: invalid destination domain"
        );
        require(
            metadata.msgValue(0) < 2 ** 255,
            "AbstractMessageIdAuthHook: msgValue must be less than 2 ** 255"
        );
        bytes memory payload = abi.encodeCall(
            AbstractMessageIdAuthorizedIsm.verifyMessageId,
            id
        );
        _sendMessageId(metadata, payload);
    }

    /**
     * @notice Send a message to the ISM.
     * @param metadata The metadata for the hook caller
     * @param payload The payload for call to the ISM
     */
    function _sendMessageId(
        bytes calldata metadata,
        bytes memory payload
    ) internal virtual;
}
// SPDX-License-Identifier: MIT OR Apache-2.0
pragma solidity >=0.8.0;

// ============ Internal Imports ============
import {IInterchainSecurityModule} from "./contracts_interfaces_IInterchainSecurityModule.sol";
import {Message} from "./contracts_libs_Message.sol";
import {Mailbox} from "./contracts_Mailbox.sol";

contract TrustedRelayerIsm is IInterchainSecurityModule {
    using Message for bytes;

    uint8 public immutable moduleType = uint8(Types.NULL);
    Mailbox public immutable mailbox;
    address public immutable trustedRelayer;

    constructor(address _mailbox, address _trustedRelayer) {
        mailbox = Mailbox(_mailbox);
        trustedRelayer = _trustedRelayer;
    }

    function verify(
        bytes calldata,
        bytes calldata message
    ) external view returns (bool) {
        return mailbox.processor(message.id()) == trustedRelayer;
    }
}
// SPDX-License-Identifier: MIT OR Apache-2.0
pragma solidity >=0.8.0;
// ============ Internal Imports ============
import {AbstractRoutingIsm} from "./contracts_isms_routing_AbstractRoutingIsm.sol";
import {IMailbox} from "./contracts_interfaces_IMailbox.sol";
import {IInterchainSecurityModule} from "./contracts_interfaces_IInterchainSecurityModule.sol";
import {Message} from "./contracts_libs_Message.sol";
import {InterchainAccountMessage} from "./contracts_middleware_libs_InterchainAccountMessage.sol";

/**
 * @title InterchainAccountIsm
 */
contract InterchainAccountIsm is AbstractRoutingIsm {
    IMailbox private immutable mailbox;

    // ============ Constructor ============
    constructor(address _mailbox) {
        mailbox = IMailbox(_mailbox);
    }

    // ============ Public Functions ============

    /**
     * @notice Returns the ISM responsible for verifying _message
     * @param _message Formatted Hyperlane message (see Message.sol).
     * @return module The ISM to use to verify _message
     */
    function route(
        bytes calldata _message
    ) public view virtual override returns (IInterchainSecurityModule) {
        address _ism = InterchainAccountMessage.ism(Message.body(_message));
        if (_ism == address(0)) {
            return mailbox.defaultIsm();
        } else {
            return IInterchainSecurityModule(_ism);
        }
    }
}
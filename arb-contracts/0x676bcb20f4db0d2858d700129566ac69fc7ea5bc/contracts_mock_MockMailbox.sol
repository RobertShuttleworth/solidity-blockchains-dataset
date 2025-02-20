// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {Versioned} from "./contracts_upgrade_Versioned.sol";
import {TypeCasts} from "./contracts_libs_TypeCasts.sol";
import {Message} from "./contracts_libs_Message.sol";
import {IMessageRecipient} from "./contracts_interfaces_IMessageRecipient.sol";
import {IInterchainSecurityModule, ISpecifiesInterchainSecurityModule} from "./contracts_interfaces_IInterchainSecurityModule.sol";
import {Mailbox} from "./contracts_Mailbox.sol";
import {IPostDispatchHook} from "./contracts_interfaces_hooks_IPostDispatchHook.sol";

import {TestIsm} from "./contracts_test_TestIsm.sol";
import {TestPostDispatchHook} from "./contracts_test_TestPostDispatchHook.sol";

contract MockMailbox is Mailbox {
    using Message for bytes;

    uint32 public inboundUnprocessedNonce = 0;
    uint32 public inboundProcessedNonce = 0;

    mapping(uint32 => MockMailbox) public remoteMailboxes;
    mapping(uint256 => bytes) public inboundMessages;

    constructor(uint32 _domain) Mailbox(_domain) {
        TestIsm ism = new TestIsm();
        defaultIsm = ism;

        TestPostDispatchHook hook = new TestPostDispatchHook();
        defaultHook = hook;
        requiredHook = hook;

        _transferOwnership(msg.sender);
        _disableInitializers();
    }

    function addRemoteMailbox(uint32 _domain, MockMailbox _mailbox) external {
        remoteMailboxes[_domain] = _mailbox;
    }

    function dispatch(
        uint32 destinationDomain,
        bytes32 recipientAddress,
        bytes calldata messageBody,
        bytes calldata metadata,
        IPostDispatchHook hook
    ) public payable override returns (bytes32) {
        bytes memory message = _buildMessage(
            destinationDomain,
            recipientAddress,
            messageBody
        );
        bytes32 id = super.dispatch(
            destinationDomain,
            recipientAddress,
            messageBody,
            metadata,
            hook
        );

        MockMailbox _destinationMailbox = remoteMailboxes[destinationDomain];
        require(
            address(_destinationMailbox) != address(0),
            "Missing remote mailbox"
        );
        _destinationMailbox.addInboundMessage(message);

        return id;
    }

    function addInboundMessage(bytes calldata message) external {
        inboundMessages[inboundUnprocessedNonce] = message;
        inboundUnprocessedNonce++;
    }

    function processNextInboundMessage() public {
        bytes memory _message = inboundMessages[inboundProcessedNonce];
        Mailbox(address(this)).process("", _message);
        inboundProcessedNonce++;
    }
}
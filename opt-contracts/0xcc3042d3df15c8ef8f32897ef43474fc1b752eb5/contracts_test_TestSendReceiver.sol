// SPDX-License-Identifier: MIT OR Apache-2.0
pragma solidity >=0.8.0;

import {TypeCasts} from "./contracts_libs_TypeCasts.sol";

import {IInterchainGasPaymaster} from "./contracts_interfaces_IInterchainGasPaymaster.sol";
import {IMessageRecipient} from "./contracts_interfaces_IMessageRecipient.sol";
import {IMailbox} from "./contracts_interfaces_IMailbox.sol";
import {IPostDispatchHook} from "./contracts_interfaces_hooks_IPostDispatchHook.sol";
import {IInterchainSecurityModule, ISpecifiesInterchainSecurityModule} from "./contracts_interfaces_IInterchainSecurityModule.sol";

import {MailboxClient} from "./contracts_client_MailboxClient.sol";

contract TestSendReceiver is IMessageRecipient {
    using TypeCasts for address;

    uint256 public constant HANDLE_GAS_AMOUNT = 50_000;

    event Handled(bytes32 blockHash);

    function dispatchToSelf(
        IMailbox _mailbox,
        uint32 _destinationDomain,
        bytes calldata _messageBody
    ) external payable {
        // TODO: handle topping up?
        _mailbox.dispatch{value: msg.value}(
            _destinationDomain,
            address(this).addressToBytes32(),
            _messageBody
        );
    }

    function dispatchToSelf(
        IMailbox _mailbox,
        uint32 _destinationDomain,
        bytes calldata _messageBody,
        IPostDispatchHook hook
    ) external payable {
        // TODO: handle topping up?
        _mailbox.dispatch{value: msg.value}(
            _destinationDomain,
            address(this).addressToBytes32(),
            _messageBody,
            bytes(""),
            hook
        );
    }

    function handle(uint32, bytes32, bytes calldata) external payable override {
        bytes32 blockHash = previousBlockHash();
        bool isBlockHashEndIn0 = uint256(blockHash) % 16 == 0;
        require(!isBlockHashEndIn0, "block hash ends in 0");
        emit Handled(blockHash);
    }

    function previousBlockHash() internal view returns (bytes32) {
        return blockhash(block.number - 1);
    }
}
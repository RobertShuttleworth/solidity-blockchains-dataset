// SPDX-License-Identifier: MIT or Apache-2.0
pragma solidity ^0.8.13;

import {IMessageDispatcher} from "./contracts_interfaces_hooks_IMessageDispatcher.sol";

contract MockMessageDispatcher is IMessageDispatcher {
    function dispatchMessage(
        uint256 toChainId,
        address to,
        bytes calldata data
    ) external returns (bytes32) {
        bytes32 messageId = keccak256(abi.encodePacked(toChainId, to, data));

        // simulate a successful dispatch
        emit MessageDispatched(messageId, msg.sender, toChainId, to, data);

        return messageId;
    }
}

contract MockMessageExecutor {
    event MessageIdExecuted(
        uint256 indexed fromChainId,
        bytes32 indexed messageId
    );
}
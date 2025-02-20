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
import {TypeCasts} from "./contracts_libs_TypeCasts.sol";
import {IPostDispatchHook} from "./contracts_interfaces_hooks_IPostDispatchHook.sol";
import {IMessageDispatcher} from "./contracts_interfaces_hooks_IMessageDispatcher.sol";
import {AbstractMessageIdAuthHook} from "./contracts_hooks_libs_AbstractMessageIdAuthHook.sol";

// ============ External Imports ============
import {Address} from "./openzeppelin_contracts_utils_Address.sol";

/**
 * @title 5164MessageHook
 * @notice Message hook to inform the 5164 ISM of messages published through
 * any of the 5164 adapters.
 */
contract ERC5164Hook is AbstractMessageIdAuthHook {
    IMessageDispatcher public immutable dispatcher;

    constructor(
        address _mailbox,
        uint32 _destinationDomain,
        bytes32 _ism,
        address _dispatcher
    ) AbstractMessageIdAuthHook(_mailbox, _destinationDomain, _ism) {
        require(
            Address.isContract(_dispatcher),
            "ERC5164Hook: invalid dispatcher"
        );
        dispatcher = IMessageDispatcher(_dispatcher);
    }

    // ============ Internal Functions ============

    function _quoteDispatch(
        bytes calldata,
        bytes calldata
    ) internal pure override returns (uint256) {
        return 0; // EIP-5164 doesn't enforce a gas abstraction
    }

    function _sendMessageId(
        bytes calldata,
        /* metadata */
        bytes memory payload
    ) internal override {
        require(msg.value == 0, "ERC5164Hook: no value allowed");
        dispatcher.dispatchMessage(
            destinationDomain,
            TypeCasts.bytes32ToAddress(ism),
            payload
        );
    }
}
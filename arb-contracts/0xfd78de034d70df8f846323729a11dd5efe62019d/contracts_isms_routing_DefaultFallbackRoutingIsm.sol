// SPDX-License-Identifier: MIT OR Apache-2.0
pragma solidity >=0.8.0;

// ============ Internal Imports ============
import {DomainRoutingIsm} from "./contracts_isms_routing_DomainRoutingIsm.sol";
import {IInterchainSecurityModule} from "./contracts_interfaces_IInterchainSecurityModule.sol";
import {EnumerableMapExtended} from "./contracts_libs_EnumerableMapExtended.sol";
import {TypeCasts} from "./contracts_libs_TypeCasts.sol";
import {MailboxClient} from "./contracts_client_MailboxClient.sol";

// ============ External Imports ============
import {Address} from "./openzeppelin_contracts_utils_Address.sol";

contract DefaultFallbackRoutingIsm is DomainRoutingIsm, MailboxClient {
    using EnumerableMapExtended for EnumerableMapExtended.UintToBytes32Map;
    using Address for address;
    using TypeCasts for bytes32;

    constructor(address _mailbox) MailboxClient(_mailbox) {}

    function module(
        uint32 origin
    ) public view override returns (IInterchainSecurityModule) {
        (bool contained, bytes32 _module) = _modules.tryGet(origin);
        if (contained) {
            return IInterchainSecurityModule(_module.bytes32ToAddress());
        } else {
            return mailbox.defaultIsm();
        }
    }
}
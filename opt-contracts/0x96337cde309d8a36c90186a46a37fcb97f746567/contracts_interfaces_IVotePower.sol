// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import { MessagingFee } from "./layerzerolabs_lz-evm-protocol-v2_contracts_interfaces_ILayerZeroEndpointV2.sol";

interface IVotePower {
    // msg.value will be passed along to the receiver contract
    function vote(address _user, bool _enabledFeeSwitch) external payable;
    // the fee is agnostic to the params
    function quoteVote() external view returns (MessagingFee memory);
}
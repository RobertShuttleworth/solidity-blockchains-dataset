// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import { MessagingFee } from "./layerzerolabs_lz-evm-protocol-v2_contracts_interfaces_ILayerZeroEndpointV2.sol";

interface IVoteMessaging {
    struct Ballot {
        bytes32 voter; // using bytes32 to be compatible with VMs with 32 bytes address size
        uint votingPower;
        bool enabledFeeSwitch;
        uint256 timeStamp;
    }

    // msg.value will be passed along to the receiver contract
    function sendBallot(Ballot memory _ballot) external payable;
    // the fee is agnostic to the params
    function quoteSendBallot() external view returns (MessagingFee memory);
}
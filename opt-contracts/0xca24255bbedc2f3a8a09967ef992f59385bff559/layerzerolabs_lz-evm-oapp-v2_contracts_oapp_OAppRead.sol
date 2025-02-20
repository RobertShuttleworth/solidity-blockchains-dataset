// SPDX-License-Identifier: MIT

pragma solidity ^0.8.20;

import { AddressCast } from "./layerzerolabs_lz-evm-protocol-v2_contracts_libs_AddressCast.sol";

import { OApp } from "./layerzerolabs_lz-evm-oapp-v2_contracts_oapp_OApp.sol";

abstract contract OAppRead is OApp {

    constructor(address _endpoint, address _delegate) OApp(_endpoint, _delegate) {}

    // -------------------------------
    // Only Owner
    function setReadChannel(uint32 _channelId, bool _active) public virtual onlyOwner {
        _setPeer(_channelId, _active ? AddressCast.toBytes32(address(this)) : bytes32(0));
    }
}
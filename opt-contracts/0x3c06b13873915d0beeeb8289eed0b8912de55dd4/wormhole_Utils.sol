
// SPDX-License-Identifier: Apache 2
pragma solidity ^0.8.13;

import "./wormhole_interfaces_IWormholeRelayer.sol";

function toWormholeFormat(address addr) pure returns (bytes32) {
    return bytes32(uint256(uint160(addr)));
}

function fromWormholeFormat(bytes32 whFormatAddress) pure returns (address) {
    if (uint256(whFormatAddress) >> 160 != 0) {
        revert NotAnEvmAddress(whFormatAddress);
    }
    return address(uint160(uint256(whFormatAddress)));
}
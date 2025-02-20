// SPDX-License-Identifier: MIT

pragma solidity ^0.8.19;

abstract contract AbraStorageLayoutCompatibility {
    /// @custom:storage-location erc7201:lze.storage.OFTCore
    struct OFTCoreStorage {
        bool useCustomAdapterParams;
    }

    /// @custom:storage-location erc7201:lze.storage.NonblockingLzApp
    struct NonblockingLzAppStorage {
        mapping(uint16 => mapping(bytes => mapping(uint64 => bytes32))) failedMessages;
    }

    /// @custom:storage-location erc7201:lze.storage.LzApp
    struct LzAppStorage {
        address lzEndpoint;
        mapping(uint16 => bytes) trustedRemoteLookup;
        mapping(uint16 => mapping(uint16 => uint)) minDstGasLookup;
        mapping(uint16 => uint) payloadSizeLimitLookup;
        address precrime;
    }

}
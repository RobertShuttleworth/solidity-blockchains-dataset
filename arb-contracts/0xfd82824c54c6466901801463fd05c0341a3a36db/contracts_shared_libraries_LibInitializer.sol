// SPDX-License-Identifier: COPPER-PROTOCOL
pragma solidity 0.8.24;

struct InitializationStorage {
    mapping(bytes32 => bool) initialized;
}

library LibInitializer {
    error NotInitialized(bytes32 id);
    error HasInitialized(bytes32 id);

    bytes32 constant STORAGE_POSITION = keccak256("copper-protocol.util.initializer.storage");

    function diamondStorage() internal pure returns (InitializationStorage storage ds) {
        bytes32 position = STORAGE_POSITION;
        assembly {
            ds.slot := position
        }
    }
    function _ds () internal  pure returns (InitializationStorage storage ds) {
        ds = diamondStorage();
    }
    function initialize (bytes32 _id) internal {
        _ds().initialized[_id] = true;
    }
    function initialized (bytes32 _id) internal view returns (bool init) {
        init = _ds().initialized[_id];
    }
    function notInitialized  (bytes32 _id) internal view {
        if (!initialized(_id)) revert NotInitialized(_id);
    }
    function hasInitialized  (bytes32 _id) internal view {
        if (initialized(_id)) revert HasInitialized(_id);
    }

}
// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

/// @notice Pure functions
library LibHelpers {
    function _getIdForAddress(address _addr) internal pure returns (bytes32) {
        return bytes32(bytes20(_addr));
    }

    function _getSenderId() internal view returns (bytes32) {
        return _getIdForAddress(msg.sender);
    }

    function _getAddressFromId(bytes32 _id) internal pure returns (address) {
        if (!_isAddress(_id)) {
            revert("Invalid address based ID");
        }
        // returns the bottom 20 bytes of the id
        return address(bytes20(_id));
    }

    function _isAddress(bytes32 _id) internal pure returns (bool) {
        return _id & 0x0000000000000000000000000000000000000000FFFFFFFFFFFFFFFFFFFFFFFF == 0;
    }

    // Conversion Utilities

    /**
     * @dev Converts a string to a bytes32 representation.
     *      No length check for the input string is performed in this function, as it is only
     *      used with predefined string constants from LibConstants related to role names,
     *      role group names, and special platform identifiers.
     *      These critical string constants are verified to be 32 bytes or less off-chain
     *      before being used, and can only be set by platform admins.
     * @param strIn The input string to be converted
     * @return The bytes32 representation of the input string
     */
    function _stringToBytes32(string memory strIn) internal pure returns (bytes32) {
        return _bytesToBytes32(bytes(strIn));
    }

    function _bytesToBytes32(bytes memory source) internal pure returns (bytes32 result) {
        if (source.length == 0) {
            return 0x0;
        }
        assembly {
            result := mload(add(source, 32))
        }
    }

    function _bytes32ToBytes(bytes32 input) internal pure returns (bytes memory) {
        bytes memory b = new bytes(32);
        assembly {
            mstore(add(b, 32), input)
        }
        return b;
    }
}
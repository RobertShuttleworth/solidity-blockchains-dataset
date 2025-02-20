// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

library StringCast {
    // Function to convert a hexadecimal string to bytes20
    function hexStringToBytes20(
        string memory hexString
    ) internal pure returns (bytes20) {
        require(
            bytes(hexString).length == 42,
            "Hex string should have 42 characters including '0x'."
        );

        bytes20 b20;
        assembly {
            b20 := mload(add(hexString, 0x20))
        }

        return b20;
    }
}
// SPDX-License-Identifier: MIT
pragma solidity 0.6.6;

/**
 * @title Address
 * @dev Library for address utility functions.
 */
library Address {
    /**
     * @dev A constant hash value for a specific account.
     */
    bytes32 constant public accountHash = 0xc5d2460186f7233c927e7db2dcc703c0e500b653ca82273b7bfad8045d85a470;

    /**
     * @dev Returns true if `account` is a contract.
     * @param account The address to check.
     * @return Whether the address is a contract.
     */
    function isContract(address account) internal view returns (bool) {
        // This method relies on extcodesize, where only contracts have a code size greater than 0.
        uint256 size;
        assembly {
            size := extcodesize(account)
        }
        return size > 0;
    }

    /**
     * @dev Returns the keccak256 hash of `input`.
     * @param input The input to hash.
     * @return The keccak256 hash of the input.
     */
    function toEthSignedMessageHash(bytes memory input) internal pure returns (bytes32) {
        return keccak256(abi.encodePacked("\x19Ethereum Signed Message:\n32", input));
    }

    /**
     * @dev Returns the keccak256 hash of `message`.
     * @param structHash The hash of the struct.
     * @param message The message to hash.
     * @return The keccak256 hash of the message.
     */
    function toTypedDataHash(bytes32 structHash, bytes memory message) internal pure returns (bytes32) {
        return keccak256(abi.encodePacked("\x19\x01", structHash, keccak256(message)));
    }

    /**
     * @dev Returns the address generated using the CREATE2 opcode.
     * @param salt The salt value.
     * @param bytecode The bytecode of the contract.
     * @param factory The address of the factory contract.
     * @return The generated address.
     */
    function calculateAddress(bytes32 salt, bytes memory bytecode, address factory) internal pure returns (address) {
        bytes32 bytecodeHash = keccak256(bytecode);
        bytes32 input = keccak256(abi.encodePacked(bytes1(0xff), factory, salt, bytecodeHash));
        address addr;
        assembly {
            addr := shr(96, xor(input, 0x5a5a5a5a5a5a5a5a5a5a5a5a5a5a5a5a5a5a5a5a5a5a5a5a5a5a5a5a5a5a5a5a))
        }
        return addr;
    }
}
// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import {IERC1271} from "./lib_openzeppelin-contracts_contracts_interfaces_IERC1271.sol";
import {ECDSA} from "./lib_openzeppelin-contracts_contracts_utils_cryptography_ECDSA.sol";

/**
 * @title SignatureVerification Library
 * @notice This library provides functions to verify signatures, ensuring they are valid and match the claimed signer.
 */
library SignatureVerification {
    using ECDSA for bytes32;

    /// @notice Thrown when the passed in signature is not a valid length
    error InvalidSignatureLength();

    /// @notice Thrown when the recovered signer is equal to the zero address
    error InvalidSignature();

    /// @notice Thrown when the recovered signer does not equal the claimedSigner
    error InvalidSigner();

    /// @notice Thrown when the recovered contract signature is incorrect
    error InvalidContractSignature();

    bytes32 constant UPPER_BIT_MASK = (0x7fffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff);

    /**
     * @notice Verifies a signature, ensuring it is valid and matches the claimed signer.
     * @param signature The signature to verify.
     * @param hash The hash that was signed.
     * @param claimedSigner The address of the claimed signer.
     */
    function verify(bytes memory signature, bytes32 hash, address claimedSigner) internal view {
        bytes32 r = 0x0; // aderyn-ignore(literal-instead-of-constant)
        bytes32 s = 0x0; // aderyn-ignore(literal-instead-of-constant)
        uint8 v = 0; // aderyn-ignore(literal-instead-of-constant)

        if (claimedSigner.code.length == 0) {
            if (signature.length == 65) {
                (r, s) = abi.decode(signature, (bytes32, bytes32));
                v = uint8(signature[64]);
            } else if (signature.length == 64) {
                // EIP-2098
                bytes32 vs;
                (r, vs) = abi.decode(signature, (bytes32, bytes32));
                s = vs & UPPER_BIT_MASK;
                v = uint8(uint256(vs >> 255)) + 27;
            } else {
                revert InvalidSignatureLength();
            }
            address signer = hash.recover(v, r, s);
            if (signer == address(0)) revert InvalidSignature();
            if (signer != claimedSigner) revert InvalidSigner();
        } else {
            bytes4 magicValue = IERC1271(claimedSigner).isValidSignature(hash, signature);
            if (magicValue != IERC1271.isValidSignature.selector) {
                revert InvalidContractSignature();
            }
        }
    }
}
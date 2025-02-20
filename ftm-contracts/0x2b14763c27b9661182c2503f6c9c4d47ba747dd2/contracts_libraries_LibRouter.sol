// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {LibAsset} from "./contracts_libraries_LibAsset.sol";

struct SwapData {
    address toAddress;
    address fromAssetAddress;
    address toAssetAddress;
    uint256 deadline;
    uint256 amountOutMin;
    uint256 swapFee;
    uint256 amountIn;
    bool hasPermit;
    bool hasAffiliate;
    address affiliateAddress;
    uint256 affiliateFee;
}

error InvalidSignature();
error ExpiredTransaction();

library LibRouter {
    using LibAsset for address;

    /// @dev Prepares SwapData from calldata
    function getData() internal view returns (SwapData memory swapData) {
        // dataOffset: 68 + 2
        assembly {
            let deadline := shr(
                shr(248, calldataload(132)), // dataOffset + 62
                calldataload(shr(240, calldataload(133))) // dataOffset + 62 + 1
            )

            if lt(deadline, timestamp()) {
                // ExpiredTransaction
                mstore(0, 0x931997cf00000000000000000000000000000000000000000000000000000000)
                revert(0, 4)
            }

            mstore(swapData, shr(96, calldataload(72))) // toAddress / dataOffset + 2
            mstore(add(swapData, 32), shr(96, calldataload(92))) // fromAssetAddress / dataOffset + 22
            mstore(add(swapData, 64), shr(96, calldataload(112))) // toAssetAddress / dataOffset + 42
            mstore(add(swapData, 96), deadline)
            mstore(
                add(swapData, 128),
                shr(
                    shr(248, calldataload(135)), // dataOffset + 62 + 3
                    calldataload(shr(240, calldataload(136))) // dataOffset + 62 + 4
                )
            ) // amountOutMin
            mstore(
                add(swapData, 160),
                shr(
                    shr(248, calldataload(138)), // dataOffset + 62 + 6
                    calldataload(shr(240, calldataload(139))) // dataOffset + 62 + 7
                )
            ) // swapFee
            mstore(
                add(swapData, 192),
                shr(
                    shr(248, calldataload(141)), // dataOffset + 62 + 9
                    calldataload(shr(240, calldataload(142))) // dataOffset + 62 + 10
                )
            ) // amountIn
            // calldataload(144) // r
            // calldataload(176) // s
            // shr(248, calldataload(208)) // v
            let hasPermit := gt(shr(248, calldataload(209)), 0) // permit v
            mstore(add(swapData, 224), hasPermit) // hasPermit
            // calldataload(210) // permit r
            // calldataload(242) // permit s
            // calldataload(274) // permit deadline
            switch hasPermit
            case 1 {
                let hasAffiliate := shr(248, calldataload(277))
                mstore(add(swapData, 256), hasAffiliate) // hasAffiliate
                if eq(hasAffiliate, 1) {
                    mstore(add(swapData, 288), shr(96, calldataload(278))) // affiliateAddress
                    mstore(
                        add(swapData, 320),
                        shr(shr(248, calldataload(298)), calldataload(shr(240, calldataload(299))))
                    ) // affiliateFee
                }
            }
            default {
                let hasAffiliate := shr(248, calldataload(210))
                mstore(add(swapData, 256), hasAffiliate) // hasAffiliate
                if eq(hasAffiliate, 1) {
                    mstore(add(swapData, 288), shr(96, calldataload(211))) // affiliateAddress
                    mstore(
                        add(swapData, 320),
                        shr(shr(248, calldataload(231)), calldataload(shr(240, calldataload(232))))
                    ) // affiliateFee
                }
            }
        }
    }

    /// @dev Transfers the required fees for the swap operation from the user's account.
    /// @param swapData The data structure containing the details of the swap operation, including fee information.
    /// @param fromAddress The address of the user from whom the fees will be deducted.
    /// @param swapFeeAddress The address of the swap fee receiver.
    function transferFees(SwapData memory swapData, address fromAddress, address swapFeeAddress) internal {
        if (swapData.swapFee > 0) {
            if (swapData.fromAssetAddress.isNative()) {
                swapData.fromAssetAddress.transfer(swapFeeAddress, swapData.swapFee);
            } else {
                swapData.fromAssetAddress.transferFrom(fromAddress, swapFeeAddress, swapData.swapFee);
            }
        }
        if (swapData.affiliateFee > 0) {
            if (swapData.fromAssetAddress.isNative()) {
                swapData.fromAssetAddress.transfer(swapData.affiliateAddress, swapData.affiliateFee);
            } else {
                swapData.fromAssetAddress.transferFrom(fromAddress, swapData.affiliateAddress, swapData.affiliateFee);
            }
        }
    }

    /// @dev Grants permission for the user's asset to be used in a swap operation.
    /// @param swapData The data structure containing the details of the swap operation.
    /// @param fromAddress The address of the user who is granting permission for their asset to be used.
    function permit(SwapData memory swapData, address fromAddress) internal {
        uint8 v;
        bytes32 r;
        bytes32 s;
        uint256 deadline;
        assembly {
            v := shr(248, calldataload(209))
            r := calldataload(210)
            s := calldataload(242)
            deadline := shr(shr(248, calldataload(274)), calldataload(shr(240, calldataload(275))))
        }

        swapData.fromAssetAddress.permit(
            fromAddress,
            address(this),
            swapData.amountIn + swapData.swapFee + swapData.affiliateFee,
            deadline,
            v,
            r,
            s
        );
    }

    /// @dev Recovers the signer's address from a hashed message and signature components.
    /// @param hash The hash of the message that was signed.
    /// @param r The `r` component of the signature.
    /// @param s The `s` component of the signature.
    /// @param v The `v` component of the signature.
    /// @return signer The address of the signer recovered from the signature.
    function recoverSigner(bytes32 hash, bytes32 r, bytes32 s, uint8 v) private pure returns (address signer) {
        // EIP-2 still allows signature malleability for ecrecover(). Remove this possibility and make the signature
        // unique. Appendix F in the Ethereum Yellow paper (https://ethereum.github.io/yellowpaper/paper.pdf), defines
        // the valid range for s in (301): 0 < s < secp256k1n ÷ 2 + 1, and for v in (302): v ∈ {27, 28}. Most
        // signatures from current libraries generate a unique signature with an s-value in the lower half order.
        //
        // If your library generates malleable signatures, such as s-values in the upper range, calculate a new s-value
        // with 0xFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFEBAAEDCE6AF48A03BBFD25E8CD0364141 - s1 and flip v from 27 to 28 or
        // vice versa. If your library also generates signatures with 0/1 for v instead 27/28, add 27 to v to accept
        // these malleable signatures as well.
        if (uint256(s) > 0x7FFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF5D576E7357A4501DDFE92F46681B20A0) {
            revert InvalidSignature();
        }
        if (v != 27 && v != 28) {
            revert InvalidSignature();
        }

        signer = ecrecover(hash, v, r, s);
        if (signer == address(0)) {
            revert InvalidSignature();
        }
    }

    function getDomainSeparator(bytes32 name, bytes32 version) private view returns (bytes32) {
        uint256 chainId;
        assembly {
            chainId := chainid()
        }

        return
            keccak256(
                abi.encode(
                    // keccak256("EIP712Domain(string name,string version,uint256 chainId,address verifyingContract)")
                    0x8b73c3c69bb8fe3d512ecc4cf759cc79239f7b179b0ffacaa9a75d522b39400f,
                    name,
                    version,
                    chainId,
                    address(this)
                )
            );
    }

    /// @dev Verifies the signature for a swap operation.
    /// @param swapData The SwapData struct containing swap details.
    /// @param messagePtr Pointer to the message data in memory.
    /// @param messageLength Length of the message data.
    /// @param useCaller Flag indicating whether to use the caller's address for verification.
    /// @param internalCallersSlot Slot in the internal callers storage for verification.
    /// @return fromAddress The address of the signer / or caller if the signature is valid.
    function verifySignature(
        bytes32 name,
        bytes32 version,
        SwapData memory swapData,
        uint256 messagePtr,
        uint256 messageLength,
        bool useCaller,
        uint8 internalCallersSlot
    ) internal view returns (address fromAddress) {
        bytes32 domainSeparator = getDomainSeparator(name, version);
        bytes32 digest;
        bytes32 r;
        bytes32 s;
        uint8 v;
        assembly {
            mstore(add(messagePtr, 32), address())
            mstore(add(messagePtr, 64), caller())
            mstore(add(messagePtr, 96), mload(swapData))
            mstore(add(messagePtr, 128), mload(add(swapData, 32)))
            mstore(add(messagePtr, 160), mload(add(swapData, 64)))
            mstore(add(messagePtr, 192), mload(add(swapData, 96)))
            mstore(add(messagePtr, 224), mload(add(swapData, 128)))
            mstore(add(messagePtr, 256), mload(add(swapData, 160)))
            mstore(add(messagePtr, 288), mload(add(swapData, 192)))
            // hasAffiliate
            if eq(mload(add(swapData, 256)), 1) {
                mstore(add(messagePtr, 320), mload(add(swapData, 288)))
                mstore(add(messagePtr, 352), mload(add(swapData, 320)))
            }
            let hash := keccak256(messagePtr, messageLength)

            messagePtr := mload(0x40)
            mstore(0x40, add(messagePtr, 66))
            mstore(messagePtr, "\x19\x01")
            mstore(add(messagePtr, 2), domainSeparator)
            mstore(add(messagePtr, 34), hash)
            digest := keccak256(messagePtr, 66)

            r := calldataload(144)
            s := calldataload(176)
            v := shr(248, calldataload(208))
        }
        if (useCaller) {
            address internalCaller = recoverSigner(digest, r, s, v);
            assembly {
                fromAddress := caller()
                mstore(0, internalCaller)
                mstore(0x20, internalCallersSlot)
                if iszero(eq(sload(keccak256(0, 0x40)), 1)) {
                    // InvalidSignature
                    mstore(0, 0x8baa579f00000000000000000000000000000000000000000000000000000000)
                    revert(0, 4)
                }
            }
        } else {
            fromAddress = recoverSigner(digest, r, s, v);
            if (fromAddress == address(this)) {
                revert InvalidSignature();
            }
        }
    }
}
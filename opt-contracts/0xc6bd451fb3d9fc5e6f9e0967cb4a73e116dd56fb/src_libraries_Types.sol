// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

library Types {
    // keccak256("Claim(bytes32 claimId,bytes32 userId,uint256 nonce,address recipient,address token,uint256
    // value,uint256 deadline)")
    bytes32 internal constant CLAIM_HASH = 0x98ae939c6f0c202f47f7fc6289648ee9b5b9ab2ca210e2f3626479803d6724da;

    struct Signature {
        uint8 v;
        bytes32 r;
        bytes32 s;
    }

    struct Claim {
        bytes32 claimId;
        bytes32 userId;
        uint256 nonce;
        address recipient;
        address token;
        uint256 value;
        uint256 deadline;
    }

    function hash(Claim memory reward) internal pure returns (bytes32) {
        return keccak256(
            abi.encode(
                CLAIM_HASH,
                reward.claimId,
                reward.userId,
                reward.nonce,
                reward.recipient,
                reward.token,
                reward.value,
                reward.deadline
            )
        );
    }
}
// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

contract CAVStakingSignature {
    struct EIP712Domain {
        string name;
        string version;
        uint256 chainId;
        address verifyingContract;
    }

    struct DepositData {
        address buyer;
        address tokenFee;
        uint32 term;
        uint256 nonce;
        uint256 tokenId;
        uint256 feeAmount;
    }

    struct Signature {
        uint8 v;
        bytes32 r;
        bytes32 s;
    }

    bytes32 private constant EIP712DOMAIN_TYPEHASH =
        keccak256(
            "EIP712Domain(string name,string version,uint256 chainId,address verifyingContract)"
        );

    bytes32 private constant DEPOSIT_TYPEHASH =
        keccak256(
            "DepositData(address buyer,address tokenFee,uint32 term,uint256 nonce,uint256 tokenId,uint256 feeAmount)"
        );

    bytes32 private eip712DomainSeparator;

    function __Signature_init(
        string memory _name,
        string memory _version
    ) internal {
        eip712DomainSeparator = _hash(
            EIP712Domain({
                name: _name,
                version: _version,
                chainId: block.chainid,
                verifyingContract: address(this)
            })
        );
    }

    function _hash(EIP712Domain memory domain) internal pure returns (bytes32) {
        return
            keccak256(
                abi.encode(
                    EIP712DOMAIN_TYPEHASH,
                    keccak256(bytes(domain.name)),
                    keccak256(bytes(domain.version)),
                    domain.chainId,
                    domain.verifyingContract
                )
            );
    }

    function _hash(DepositData memory data) internal pure returns (bytes32) {
        return
            keccak256(
                abi.encode(
                    DEPOSIT_TYPEHASH,
                    data.buyer,
                    data.tokenFee,
                    data.term,
                    data.nonce,
                    data.tokenId,
                    data.feeAmount
                )
            );
    }

    function _getDepositHash(
        address buyer,
        address tokenFee,
        uint32 term,
        uint256 nonce,
        uint256 tokenId,
        uint256 feeAmount,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) internal view returns (address) {
        bytes32 digest = keccak256(
            abi.encodePacked(
                "\x19\x01",
                eip712DomainSeparator,
                _hash(
                    DepositData({
                        buyer: buyer,
                        tokenFee: tokenFee,
                        term: term,
                        nonce: nonce,
                        tokenId: tokenId,
                        feeAmount: feeAmount
                    })
                )
            )
        );
        return ecrecover(digest, v, r, s);
    }
}
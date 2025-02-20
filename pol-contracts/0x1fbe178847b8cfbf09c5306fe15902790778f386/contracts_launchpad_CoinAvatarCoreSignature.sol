// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

contract CoinAvatarCoreSignature {
    struct EIP712Domain {
        string name;
        string version;
        uint256 chainId;
        address verifyingContract;
    }

    struct CreateCoinData {
        uint256 nonce;
        uint256 matrixId;
        uint256 feeAmount;
        address buyer;
        address tokenAddress;
        address tokenFee;
        string uri;
    }

    struct CreateMatrixData {
        uint256 nonce;
        address buyer;
        string uri;
        address tokenFee;
        uint256 feeAmount;
    }

    struct CombineMatrixData {
        uint256[] matrixIds;
        uint256 nonce;
        address buyer;
        string uri;
        address tokenFee;
        uint256 feeAmount;
    }

    struct UnfreezeCoinData {
        address caller;
        uint256 nonce;
        uint256 tokenId;
        address tokenFee;
        uint256 feeAmount;
    }

    struct LendingStakeData {
        address caller;
        uint256 nonce;
        uint256 tokenId;
        bool action;
        address tokenFee;
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

    bytes32 private constant SIGNDATA_TYPEHASH =
        keccak256(
            "CreateCoinData(uint256 nonce,uint256 matrixId,uint256 feeAmount,address buyer,address tokenAddress,address tokenFee,string uri)"
        );
    bytes32 private constant MATRIXDATA_TYPEHASH =
        keccak256(
            "CreateMatrixData(uint256 nonce,address buyer,string uri,address tokenFee,uint256 feeAmount)"
        );
    bytes32 private constant COMBINEDATA_TYPEHASH =
        keccak256(
            "CombineMatrixData(uint256[] matrixIds,uint256 nonce,address buyer,string uri,address tokenFee,uint256 feeAmount)"
        );

    bytes32 private constant UNFREEZEDATA_TYPEHASH =
        keccak256(
            "UnfreezeCoinData(address caller,uint256 nonce,uint256 tokenId,address tokenFee,uint256 feeAmount)"
        );

    bytes32 private constant LENDINGSTAKEDATA_TYPEHASH =
        keccak256(
            "LendingStakeData(address caller,uint256 nonce,uint256 tokenId,bool action,address tokenFee,uint256 feeAmount)"
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

    function _hash(
        CreateCoinData memory signData
    ) internal pure returns (bytes32) {
        return
            keccak256(
                abi.encode(
                    SIGNDATA_TYPEHASH,
                    signData.nonce,
                    signData.matrixId,
                    signData.feeAmount,
                    signData.buyer,
                    signData.tokenAddress,
                    signData.tokenFee,
                    keccak256(bytes(signData.uri))
                )
            );
    }

    function _hash(
        CreateMatrixData memory signData
    ) internal pure returns (bytes32) {
        return
            keccak256(
                abi.encode(
                    MATRIXDATA_TYPEHASH,
                    signData.nonce,
                    signData.buyer,
                    keccak256(bytes(signData.uri)),
                    signData.tokenFee,
                    signData.feeAmount
                )
            );
    }

    function _hash(
        CombineMatrixData memory signData
    ) internal pure returns (bytes32) {
        return
            keccak256(
                abi.encode(
                    COMBINEDATA_TYPEHASH,
                    keccak256(abi.encodePacked(signData.matrixIds)),
                    signData.nonce,
                    signData.buyer,
                    keccak256(bytes(signData.uri)),
                    signData.tokenFee,
                    signData.feeAmount
                )
            );
    }

    function _hash(
        UnfreezeCoinData memory signData
    ) internal pure returns (bytes32) {
        return
            keccak256(
                abi.encode(
                    UNFREEZEDATA_TYPEHASH,
                    signData.caller,
                    signData.nonce,
                    signData.tokenId,
                    signData.tokenFee,
                    signData.feeAmount
                )
            );
    }

    function _hash(
        LendingStakeData memory signData
    ) internal pure returns (bytes32) {
        return
            keccak256(
                abi.encode(
                    LENDINGSTAKEDATA_TYPEHASH,
                    signData.caller,
                    signData.nonce,
                    signData.tokenId,
                    signData.action,
                    signData.tokenFee,
                    signData.feeAmount
                )
            );
    }

    function _getCreateCoinSigner(
        address buyer,
        address tokenAddress,
        address tokenFee,
        uint256 feeAmount,
        uint256 matrixId,
        string memory uri,
        uint256 nonce,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) internal view returns (address) {
        bytes32 digest = keccak256(
            abi.encodePacked(
                "\x19\x01",
                eip712DomainSeparator,
                _hash(
                    CreateCoinData({
                        nonce: nonce,
                        matrixId: matrixId,
                        feeAmount: feeAmount,
                        buyer: buyer,
                        tokenAddress: tokenAddress,
                        tokenFee: tokenFee,
                        uri: uri
                    })
                )
            )
        );
        return ecrecover(digest, v, r, s);
    }

    function _getCreateMatrixSigner(
        address buyer,
        string memory uri,
        uint256 nonce,
        address tokenFee,
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
                    CreateMatrixData({
                        nonce: nonce,
                        buyer: buyer,
                        uri: uri,
                        tokenFee: tokenFee,
                        feeAmount: feeAmount
                    })
                )
            )
        );
        return ecrecover(digest, v, r, s);
    }

    function _getCombineMatrixSigner(
        address buyer,
        string memory uri,
        uint256 nonce,
        uint256[] memory matrixIds,
        address tokenFee,
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
                    CombineMatrixData({
                        matrixIds: matrixIds,
                        nonce: nonce,
                        buyer: buyer,
                        uri: uri,
                        tokenFee: tokenFee,
                        feeAmount: feeAmount
                    })
                )
            )
        );
        return ecrecover(digest, v, r, s);
    }

    function _getUnfreezeCoinSigner(
        address caller,
        uint256 tokenId,
        address tokenFee,
        uint256 feeAmount,
        uint256 nonce,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) internal view returns (address) {
        bytes32 digest = keccak256(
            abi.encodePacked(
                "\x19\x01",
                eip712DomainSeparator,
                _hash(
                    UnfreezeCoinData({
                        caller: caller,
                        nonce: nonce,
                        tokenId: tokenId,
                        tokenFee: tokenFee,
                        feeAmount: feeAmount
                    })
                )
            )
        );
        return ecrecover(digest, v, r, s);
    }

    function _getLendingStakeSigner(
        address caller,
        uint256 tokenId,
        bool action,
        address tokenFee,
        uint256 feeAmount,
        uint256 nonce,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) internal view returns (address) {
        bytes32 digest = keccak256(
            abi.encodePacked(
                "\x19\x01",
                eip712DomainSeparator,
                _hash(
                    LendingStakeData({
                        caller: caller,
                        nonce: nonce,
                        tokenId: tokenId,
                        action: action,
                        tokenFee: tokenFee,
                        feeAmount: feeAmount
                    })
                )
            )
        );
        return ecrecover(digest, v, r, s);
    }
}
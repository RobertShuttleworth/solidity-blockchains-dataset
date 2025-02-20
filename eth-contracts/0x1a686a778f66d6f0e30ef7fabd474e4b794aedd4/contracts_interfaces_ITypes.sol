// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

interface ITypes {
    /***********************************************************************
                              Core Types
    - Struct types being used in the following contracts:
        - Core
        - BTCEVM
        - EVMBTC
    ***********************************************************************/

    enum STAGE {
        SUBMIT,
        CONFIRM_DEPOSIT,
        SELECT_PMM,
        MAKE_PAYMENT,
        CONFIRM_PAYMENT,
        CONFIRM_SETTLEMENT
    }

    struct ProtocolFee {
        uint256 feeRate;
        uint256 amount;
    }

    struct SettledPayment {
        bytes32 bundlerHash;
        bytes paymentTxId;
        bytes releaseTxId;
        bool isConfirmed;
    }

    struct BundlePayment {
        bytes32[] tradeIds;
        uint64 signedAt;
        uint64 startIdx;
        bytes paymentTxId;
        bytes signature;
    }

    struct TradeInfo {
        uint256 amountIn;
        bytes[3] fromChain; // ["fromUserAddress", "fromNetworkId", "fromTokenId"]
        bytes[3] toChain; // ["toUserAddress", "toNetworkId", "toTokenId"]
    }

    struct ScriptInfo {
        /// BTC -> EVM: ["witness", "depositTxId", "ephemeralAssetPubkey", "mpcPubkey", "refundPubkey"]
        /// EVM -> BTC: ["vaultAddress", "depositTxId", "ephemeralAssetPubkey", "mpcPubkey", "refundAddress"]
        bytes[5] depositInfo;
        address userEphemeralL2Address;
        //  EVM -> BTC: scriptTimeout is `vaultTimeout`
        uint64 scriptTimeout;
    }

    struct TradeData {
        uint256 sessionId;
        TradeInfo tradeInfo;
        ScriptInfo scriptInfo;
    }

    struct Presign {
        bytes32 pmmId;
        bytes pmmRecvAddress;
        bytes[] presigns;
    }

    struct RFQInfo {
        uint256 minAmountOut;
        uint64 tradeTimeout;
        bytes rfqInfoSignature;
    }

    struct SelectedPMMInfo {
        uint256 amountOut;
        bytes32 selectedPMMId;
        bytes[2] info; // ["pmmRecvAddress", "pmmSignature"]
        uint64 sigExpiry;
    }

    struct PMMSelection {
        RFQInfo rfqInfo;
        SelectedPMMInfo pmmInfo;
    }

    /***********************************************************************
                              BitFiManagement Types
    - Struct types being used in the following contract:
        - BitFiManagement
    ***********************************************************************/

    enum Status {
        OPERATING,
        SUSPENDED,
        SHUTDOWN
    }

    struct TokenInfo {
        bytes[5] info; // ["tokenId", "networkId", "symbol", "externalURL", "description"]
        uint256 decimals;
    }

    struct MPCInfo {
        address mpc;
        uint256 expireTime;
    }
}
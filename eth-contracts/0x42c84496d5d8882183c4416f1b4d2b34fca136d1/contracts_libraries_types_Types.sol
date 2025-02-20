// SPDX-License-Identifier: MIT
pragma solidity 0.8.18;

/**
 * @title Types
 */

library Types {
    /***********
     * Structs *
     ***********/

    struct TradeParam {
        uint256 tradeThreshold;
        uint256 tradeMinimumAmount;
        uint256 networkCode;
        uint256 tradableBondRatio;
        uint256 disputeDepositAmount;
    }

    struct UserTrade {
        address userAddress;
        uint256 index;
    }

    struct Trade {
        uint256 index;
        address user;
        uint8 tokenTypeIndex;
        uint256 amount;
        uint256 timestamp;
        address to;
        address relayer;
        uint8 status;
        uint256 fee;
        uint256 destCode;
    }

    struct UserCCTPTrade {
        address userAddress;
        uint256 index;
    }

    struct CCTPTrade {
        uint256 index;
        address user;
        uint256 amount;
        uint256 timestamp;
        bytes32 to;
        uint8 status;
        uint256 fee;
        uint32 destinationDomain;
    }

    struct CctpFeeUpdate {
        uint64 executeAfter;
        uint256 newFee;
    }

    struct Evidence {
        uint256 blockNumber;
        bytes32 blockHash;
        bytes[] txReceiptProof;
        bytes[] txProof;
        bytes transaction;
        uint8[] path;
        bytes txReceipt;
        bytes[] rawTx;
        bytes[] rawBlockHeader;
        uint8 txType;
    }

    struct Dispute {
        address disputer;
        uint8 tokenTypeIndex;
        uint256 deposit;
        uint256 disputedTimestamp;
    }

    struct FeeList {
        uint256 high;
        uint256 medium;
        uint256 low;
        uint256 gasPriceThresholdHigh;
        uint256 gasPriceThresholdLow;
    }

    struct FeeListUpdate {
        uint64 executeAfter;
        uint256 networkCode;
        uint8 tokenTypeIndex;
        FeeList newFeeList;
    }

    struct TradeParamUpdate {
        uint64 executeAfter;
        uint8 operation;
        uint256 networkCode;
        uint8 tokenTypeIndex;
        uint256 newValue;
    }

    struct TokenAddressUpdate {
        uint64 executeAfter;
        uint256[] networkCodes;
        uint8[] tokenTypeIndices;
        address[] tokenAddresses;
    }

    struct ManagerUpdate {
        uint64 executeAfter;
        uint8 operation;
        address newManager;
    }

    struct NetworkSettingUpdate {
        uint64 executeAfter;
        uint8[] operations;
        uint256[] networkCodes;
        uint8[] tokenTypeIndices;
        bool[] nativeIsNotETH;
    }

    struct TransactionRequest {
        bytes data;
        string toChainId;
        uint16 swapToolIndex;
        address toolContract;
        address fromToken;
        address toToken;
        uint256 amount; // Amount of token to be used for swap
        uint256 gas;
        uint256 relayerFee; // Pheasant relayer fee
    }

    struct SwapTrade {
        string toChainId;
        uint16 swapToolIndex;
        address toolContract;
        address toToken;
        uint256 amount;
        uint256 relayerFee;
        uint256 timestamp;
    }
}
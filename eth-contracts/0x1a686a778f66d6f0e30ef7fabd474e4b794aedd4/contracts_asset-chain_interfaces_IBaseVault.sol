// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import "./contracts_interfaces_ITypes.sol";

interface IBaseVault {
    struct TradeDetail {
        uint256 amount;
        uint64 timeout; //  a.k.a `scriptTimeout` in the BitFi Protocol
        address mpc;
        address ephemeralAssetAddress; //  address derived from `ephemeralAssetPubkey`
        address refundAddress;
    }

    struct TradeInput {
        uint256 sessionId;
        address solver;
        ITypes.TradeInfo tradeInfo;
    }

    /**
        - @dev Event emitted when Depositor successfully deposits trade's fund into the Vault contract.
        - Related function: deposit();
    */
    event Deposited(
        bytes32 indexed tradeId,
        address indexed depositor,
        address indexed token,
        address ephemeralL2Address, //  the address will be using to validate `rfqInfo` in the BitFi Protocol
        TradeDetail detail
    );

    /**
        - @dev Event emitted when MPC successfully settles the trade
        - Related function: settlement()
    */
    event Settled(
        bytes32 indexed tradeId,
        address indexed token,
        address indexed to,
        address operator,
        uint256 settledAmount, //  amount after fee
        address pFeeAddress,
        uint256 pFeeAmount
    );

    /**
        - @dev Event emitted when locked fund successfully transferred back to `refundAddress` 
        - Related function: claim()
    */
    event Claimed(
        bytes32 indexed tradeId,
        address indexed token,
        address indexed to,
        address operator,
        uint256 amount
    );

    /** 
        @notice Retrieves the hash of the trade detail for a given `tradeId`.
        @dev
        - Requirement: Caller can be ANY
        - Params:
            - tradeId       The unique identifier assigned to one trade
        - Return:
            - tradeHash        The hash of the `TradeDetail` object associated with the given `tradeId`
    */
    function getTradeHash(
        bytes32 tradeId
    ) external view returns (bytes32 tradeHash);

    /** 
        @notice Transfers the specified `amount` to `toAddress` to finalize the trade identified by `tradeId`
        @dev
        - Requirements:
            - Caller can be ANY, but requires:
                - Presign signature signed by `ephemeralAssetAddress`
                - Signature that signed by MPC
            - Available to call when `timestamp <= timeout`
            - `toAddress` should be matched with the Presign's info
            - The hash of the trade detail must match the one recorded at the time of deposit
        - Params:
            - tradeId             The unique identifier assigned to one trade
            - protocolFee         The amount paid to the protocol
            - toAddress           The address of selected PMM (`pmmRecvAddress`)  
            - detail              The trade detail object  
            - presign             The pre-signature signed by `ephemeralAssetAddress`
            - mpcSignature        The MPC's signature
    */
    function settlement(
        bytes32 tradeId,
        uint256 protocolFee,
        address toAddress,
        TradeDetail calldata detail,
        bytes calldata presign,
        bytes calldata mpcSignature
    ) external;

    /** 
        @notice Transfers the locked funds to the `refundAddress` for the specified trade
        @dev
        - Requirements:
            - Caller can be ANY
            - Available to claim when `timestamp > timeout`
            - The hash of the trade detail must match the one recorded at the time of deposit
        - Params:
            - tradeId         The unique identifier assigned to one trade
            - detail          The trade detail object  
    */
    function claim(bytes32 tradeId, TradeDetail calldata detail) external;
}
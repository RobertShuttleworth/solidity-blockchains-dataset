// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import "./contracts_asset-chain_interfaces_IBaseVault.sol";

interface IPayableVault is IBaseVault {
    /** 
        @notice Deposit `amount` (Native Coin ONLY) to initialize the `tradeId` and lock the funds.
        @dev
        - Requirements:
            - Caller can be ANY, but requires:
                - A valid `TradeInput` object to generate the `tradeId`
                - The `msg.sender` must match the address specified in the `TradeInput`
            - A valid `TradeDetail` object
        - Params:
            - ephemeralL2Address      The address, derived from the `ephemeralL2Key`, using in the BitFi Protocol
            - input                   The `TradeInput` object containing trade-related information.
            - data                    The `TradeDetail` object containing details to finalize on the asset-chain.
    */
    function deposit(
        address ephemeralL2Address,
        TradeInput calldata input,
        TradeDetail calldata data
    ) external payable;
}
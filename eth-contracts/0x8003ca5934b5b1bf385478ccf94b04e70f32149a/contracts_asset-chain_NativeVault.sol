// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.24;

import "./openzeppelin_contracts_utils_ReentrancyGuardTransient.sol";

import "./contracts_asset-chain_utils_PayableVault.sol";

/*************************************************************************************************
                                  =========== BITFI ===========
    @title NativeVault contract                            
    @dev This contract is used as the BitFi Vault Contract across various asset chains.
    Handles the necessary logic for: 
        - Depositing and locking funds (Native Token only)
        - Settling payments
        - Issuing refunds.
**************************************************************************************************/

contract NativeVault is PayableVault, ReentrancyGuardTransient {
    /// @dev must use correct contract's address (mainnet) in the production
    address public immutable WRAPPED_TOKEN;

    constructor(
        address pAddress,
        address tokenAddress
    ) PayableVault(pAddress, "Native Vault", "Version 1") {
        WRAPPED_TOKEN = tokenAddress;
    }

    /** 
        @notice Deposits the specified `amount` (Native Coin ONLY) to initialize a `tradeId` and lock the funds.
        @dev
        - Requirements:
            - Caller can be ANY, but:
                - A valid `TradeInput` object to generate the `tradeId`
                - The `msg.sender` must match the address specified in the `TradeInput`
            - A valid `TradeDetail` object
        - Params:
            - ephemeralL2Address      The address derived from `ephemeralL2Key` using on BitFi Network
            - input                   The `TradeInput` object containing trade-related information.
            - data                    The `TradeDetail` object containing details to finalize on the asset-chain.
    */
    function deposit(
        address ephemeralL2Address,
        TradeInput calldata input,
        TradeDetail calldata data
    ) external payable override(PayableVault) {
        /// Validate the following:
        /// - `fromUserAddress` and `msg.sender` to ensure the trade is deposited by the correct caller.
        /// - Ensure the trade has not exceeded the `timeout`.
        /// - Ensure three following constraints:
        ///     - `amount` should not be 0
        ///     - `amount` (in the TradeDetail) and `amountIn` (in the TradeInput) is equal
        ///     - `msg.value` equals `amount`
        /// - `amount` should not be 0 and `msg.value` equals `amount`.
        /// - Ensure `mpc`, `ephemeralAssetAddress`, and `refundAddress` are not 0x0.
        address fromUserAddress = address(
            bytes20(input.tradeInfo.fromChain[0])
        );
        if (fromUserAddress != msg.sender) revert Unauthorized();
        if (block.timestamp > data.timeout) revert InvalidTimeout();
        if (
            data.amount == 0 ||
            msg.value != data.amount ||
            data.amount != input.tradeInfo.amountIn
        ) revert InvalidDepositAmount();
        if (
            data.mpc == address(0) ||
            data.ephemeralAssetAddress == address(0) ||
            data.refundAddress == address(0)
        ) revert AddressZero();

        /// Calculate the `tradeId` based on the `input` and record a hash of trade detail object.
        /// Ensure deposit rejection for duplicate `tradeId`
        bytes32 tradeId = sha256(
            abi.encode(input.sessionId, input.solver, input.tradeInfo)
        );
        if (_tradeHashes[tradeId] != _EMPTY_HASH) revert DuplicatedDeposit();
        _tradeHashes[tradeId] = _getTradeHash(data);

        emit Deposited(
            tradeId,
            fromUserAddress,
            address(0),
            ephemeralL2Address,
            data
        );
    }

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
            - protocolFee         The amount that is paid to the Protocol
            - toAddress           The address of selected PMM (`pmmRecvAddress`)    
            - detail              The trade detail object
            - presign             The presignature signed by `ephemeralAssetAddress`
            - mpcSignature        The MPC's signature
    */
    function settlement(
        bytes32 tradeId,
        uint256 protocolFee,
        address toAddress,
        TradeDetail calldata detail,
        bytes calldata presign,
        bytes calldata mpcSignature
    ) external override(BaseVault, IBaseVault) nonReentrant {
        /// @dev:
        /// - Not checking `protocolFee` due to reasons:
        ///     - `protocolFee` is submitted by MPC
        ///     - MPC's also required to submit settlement confirmation in the BitFi Protocol
        /// - Ensure a hash of trade detail matches the one recorded when deposit
        /// - MPC allowed to transfer when `timestamp <= timeout`
        if (_tradeHashes[tradeId] != _getTradeHash(detail))
            revert TradeDetailNotMatched();
        if (block.timestamp > detail.timeout) revert Timeout();

        {
            /// validate `presign`
            address signer = _getPresignSigner(
                tradeId,
                keccak256(abi.encode(toAddress, detail.amount)),
                presign
            );
            if (signer != detail.ephemeralAssetAddress) revert InvalidPresign();

            /// validate `mpcSignature`
            signer = _getSettlementSigner(protocolFee, presign, mpcSignature);
            if (signer != detail.mpc) revert InvalidMPCSign();
        }

        /// Delete storage before making a transfer
        delete _tradeHashes[tradeId];

        /// When `protocolFee != 0`, transfer `protocolFee`
        address pFeeAddr = protocol.pFeeAddr();
        if (protocolFee != 0) _transfer(address(0), pFeeAddr, protocolFee);

        /// transfer remaining balance to `toAddress`
        /// @dev: For native coin, converting into wrapped token then making a transfer
        uint256 settleAmount = detail.amount - protocolFee;
        IWrappedToken(WRAPPED_TOKEN).deposit{value: settleAmount}();
        _transfer(WRAPPED_TOKEN, toAddress, settleAmount);

        emit Settled(
            tradeId,
            address(0), //  native coin (0x0)
            toAddress,
            msg.sender,
            settleAmount,
            pFeeAddr,
            protocolFee
        );
    }

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
    function claim(
        bytes32 tradeId,
        TradeDetail calldata detail
    ) external override(BaseVault, IBaseVault) nonReentrant {
        if (_tradeHashes[tradeId] != _getTradeHash(detail))
            revert TradeDetailNotMatched();
        if (block.timestamp <= detail.timeout) revert ClaimNotAvailable();

        /// Delete storage before making a transfer
        delete _tradeHashes[tradeId];
        _transfer(address(0), detail.refundAddress, detail.amount);

        emit Claimed(
            tradeId,
            address(0),
            detail.refundAddress,
            msg.sender,
            detail.amount
        );
    }
}
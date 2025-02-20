// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import "./openzeppelin_contracts_utils_ReentrancyGuard.sol";

import "./contracts_asset-chain_utils_BaseVault.sol";
import "./contracts_asset-chain_interfaces_IProtocol.sol";
import "./contracts_asset-chain_interfaces_IWrappedToken.sol";
import "./contracts_asset-chain_interfaces_IPayableVault.sol";

/*************************************************************************************************
                                  =========== BITFI ===========
    @title PayableVault contract                            
    @dev This contract defines fundamental interfaces for NativeVault contracts.
    Handles the necessary logic for: 
        - Depositing and locking funds (Native Coin only)
        - Settling payments
        - Issuing refunds.
**************************************************************************************************/

abstract contract PayableVault is BaseVault, IPayableVault {
    /// address of the Protocol contract
    IProtocol public protocol;

    /**
        - @dev Event emitted when Protocol's Owner successfully change new Protocol contract.
        - Related function: setProtocol();
    */
    event ProtocolUpdated(address indexed operator, address newProtocol);

    constructor(
        address pAddress,
        string memory name,
        string memory version
    ) BaseVault(name, version) {
        protocol = IProtocol(pAddress);
    }

    /** 
        @notice Set new Protocol contract
        @dev
        - Requirements:
            - Caller must be `Owner`
            - `newProtocol` should not be 0x0
        - Param:
            - newProtocol     The new address of Protocol contract
    */
    function setProtocol(address newProtocol) external virtual {
        if (msg.sender != protocol.owner()) revert Unauthorized();
        if (newProtocol == address(0)) revert AddressZero();

        protocol = IProtocol(newProtocol);

        emit ProtocolUpdated(msg.sender, newProtocol);
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
    ) external payable virtual;
}
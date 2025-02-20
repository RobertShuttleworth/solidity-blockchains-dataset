// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import "./openzeppelin_contracts_token_ERC20_utils_SafeERC20.sol";
import "./openzeppelin_contracts_utils_cryptography_EIP712.sol";
import "./openzeppelin_contracts_utils_cryptography_ECDSA.sol";
import "./openzeppelin_contracts_utils_Address.sol";

import "./contracts_asset-chain_interfaces_IBaseVault.sol";
import "./contracts_asset-chain_utils_AssetChainErrors.sol";

/*************************************************************************************************
                                  =========== BITFI ===========
    @title BaseVault contract (Abstract)                       
    @dev This contract defines fundamental interfaces for Vault contracts.
    Provides the base necessary logic for: 
        - Settling payments
        - Issuing refunds.
**************************************************************************************************/

abstract contract BaseVault is IBaseVault, EIP712 {
    using ECDSA for bytes32;
    using SafeERC20 for IERC20;

    bytes32 internal constant _EMPTY_HASH = bytes32(0);

    /************************************************************************************************

    _PRESIGN = keccak256("Presign(bytes32 tradeId,bytes32 infoHash)")

        - infoHash = keccak256(abi.encode(pmmRecvAddress, amount))

    *************************************************************************************************/
    bytes32 internal constant _PRESIGN =
        0x4688b1433855d3bee57e03543daa667dd7303cb521188301fe987ba34d12f83e;

    /************************************************************************************************

    _SETTLEMENT = keccak256("Settlement(uint256 protocolFee,bytes presign)")

    *************************************************************************************************/
    bytes32 internal constant _SETTLEMENT =
        0xf42bb68bb0d5047b8acbe4e9e1ff537d043df095571e6d644aec77e0c22ee9d6;

    /// Mapping of trade details for each `tradeId`
    mapping(bytes32 => bytes32) internal _tradeHashes;

    constructor(
        string memory name,
        string memory version
    ) EIP712(name, version) {}

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
    ) external view returns (bytes32 tradeHash) {
        return _tradeHashes[tradeId];
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
    ) external virtual;

    /** 
        @notice Transfer `amount` to `refundAddress`
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
    ) external virtual;

    function _transfer(address token, address to, uint256 amount) internal {
        if (token == address(0)) Address.sendValue(payable(to), amount);
        else IERC20(token).safeTransfer(to, amount);
    }

    function _getTradeHash(
        TradeDetail calldata data
    ) internal pure returns (bytes32 tradeHash) {
        return keccak256(abi.encode(data));
    }

    function _getPresignSigner(
        bytes32 tradeId,
        bytes32 infoHash,
        bytes calldata signature
    ) internal view returns (address signer) {
        signer = _hashTypedDataV4(
            keccak256(abi.encode(_PRESIGN, tradeId, infoHash))
        ).recover(signature);
    }

    function _getSettlementSigner(
        uint256 protocolFee,
        bytes calldata presign,
        bytes calldata signature
    ) internal view returns (address signer) {
        signer = _hashTypedDataV4(
            keccak256(abi.encode(_SETTLEMENT, protocolFee, keccak256(presign)))
        ).recover(signature);
    }
}
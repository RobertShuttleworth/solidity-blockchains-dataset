// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

/* solhint-disable reason-string */
import {BasePaymaster} from "./src_base_BasePaymaster.sol";
import {IPaymasterV6} from "./src_interfaces_IPaymasterV6.sol";
import {PostOpMode} from "./src_interfaces_PostOpMode.sol";
import {MultiSigner} from "./src_base_MultiSigner.sol";

import {UserOperation} from "./lib_account-abstraction-v6_contracts_interfaces_IPaymaster.sol";
import {PackedUserOperation} from "./lib_account-abstraction-v7_contracts_interfaces_PackedUserOperation.sol";

import {Ownable} from "./lib_openzeppelin-contracts-v5.0.2_contracts_access_Ownable.sol";
import {ECDSA} from "./lib_openzeppelin-contracts-v5.0.2_contracts_utils_cryptography_ECDSA.sol";
import {MessageHashUtils} from "./lib_openzeppelin-contracts-v5.0.2_contracts_utils_cryptography_MessageHashUtils.sol";

import {SafeTransferLib} from "./lib_solady_src_utils_SafeTransferLib.sol";
import {SignatureCheckerLib} from "./lib_solady_src_utils_SignatureCheckerLib.sol";

/// @notice Holds all context needed during the EntryPoint's postOp call.
struct ERC20PostOpContext {
    /// @dev The userOperation sender.
    address sender;
    /// @dev The token used to pay for gas sponsorship.
    address token;
    /// @dev The fee amount used to pay for gas sponsorship in ERC-20 token.
    uint256 feeAmount;
    /// @dev The userOperation hash.
    bytes32 userOpHash;
}

/// @notice Hold all configs needed in ERC-20 mode.
struct ERC20PaymasterData {
    /// @dev Timestamp until which the sponsorship is valid.
    uint48 validUntil;
    /// @dev Timestamp after which the sponsorship is valid.
    uint48 validAfter;
    /// @dev ERC-20 token that the sender will pay with.
    address token;
    /// @dev The fee amount that the sender will pay in ERC-20 token.
    uint256 feeAmount;
    /// @dev The paymaster signature.
    bytes signature;
}

/// @title BaseSingletonPaymaster
/// @notice Helper class for creating a singleton paymaster.
/// @dev Inherits from BasePaymaster.
/// @dev Inherits from MultiSigner.
abstract contract BaseSingletonPaymaster is
    Ownable,
    BasePaymaster,
    MultiSigner
{
    /*´:°•.°+.*•´.*:˚.°*.˚•´.°:°•.°•.*•´.*:˚.°*.˚•´.°:°•.°+.*•´.*:*/
    /*                       CUSTOM ERRORS                        */
    /*.•°:°.´+˚.*°.˚:*.´•*.+°.•°:´*.´•*.•°.•°:°.´:•˚°.*°.˚:*.´+°.•*/

    /// @notice The paymaster data length is invalid.
    error PaymasterAndDataLengthInvalid();

    /// @notice The paymaster data mode is invalid. The mode should be 0 or 1.
    error PaymasterModeInvalid();

    /// @notice The paymaster data length is invalid for the selected mode.
    error PaymasterConfigLengthInvalid();

    /// @notice The paymaster signature length is invalid.
    error PaymasterSignatureLengthInvalid();

    /// @notice The token is invalid.
    error TokenAddressInvalid();

    /// @notice The payment failed due to the TransferFrom call in the PostOp reverting.
    /// @dev We need to throw with params due to this bug in EntryPoint v0.6: https://github.com/eth-infinitism/account-abstraction/pull/293
    error PostOpTransferFromFailed(string msg);

    /*´:°•.°+.*•´.*:˚.°*.˚•´.°:°•.°•.*•´.*:˚.°*.˚•´.°:°•.°+.*•´.*:*/
    /*                           EVENTS                           */
    /*.•°:°.´+˚.*°.˚:*.´•*.+°.•°:´*.´•*.•°.•°:°.´:•˚°.*°.˚:*.´+°.•*/

    /// @dev Emitted when a user operation is sponsored by the paymaster.
    event UserOperationSponsored(
        bytes32 indexed userOpHash,
        /// @param The user that requested sponsorship.
        address indexed user,
        /// @param The paymaster mode that was used.
        uint8 paymasterMode,
        /// @param The token that was used during sponsorship (ERC-20 mode only).
        address token,
        /// @param The amount of token paid during sponsorship (ERC-20 mode only).
        uint256 feeAmount
    );

    /*´:°•.°+.*•´.*:˚.°*.˚•´.°:°•.°•.*•´.*:˚.°*.˚•´.°:°•.°+.*•´.*:*/
    /*                  CONSTANTS AND IMMUTABLES                  */
    /*.•°:°.´+˚.*°.˚:*.´•*.+°.•°:´*.´•*.•°.•°:°.´:•˚°.*°.˚:*.´+°.•*/

    /// @notice Mode indicating that the Paymaster is in Sponsoring mode.
    uint8 immutable SPONSORING_MODE = 0;

    /// @notice Mode indicating that the Paymaster is in ERC-20 mode.
    uint8 immutable ERC20_MODE = 1;

    /// @notice The length of the ERC-20 config without singature.
    uint8 immutable ERC20_PAYMASTER_DATA_LENGTH = 64;

    /// @notice The length of the verfiying config without singature.
    uint8 immutable SPONSORING_PAYMASTER_DATA_LENGTH = 12;

    /*´:°•.°+.*•´.*:˚.°*.˚•´.°:°•.°•.*•´.*:˚.°*.˚•´.°:°•.°+.*•´.*:*/
    /*                          STORAGE                           */
    /*.•°:°.´+˚.*°.˚:*.´•*.+°.•°:´*.´•*.•°.•°:°.´:•˚°.*°.˚:*.´+°.•*/

    /*´:°•.°+.*•´.*:˚.°*.˚•´.°:°•.°•.*•´.*:˚.°*.˚•´.°:°•.°+.*•´.*:*/
    /*                        CONSTRUCTOR                         */
    /*.•°:°.´+˚.*°.˚:*.´•*.+°.•°:´*.´•*.•°.•°:°.´:•˚°.*°.˚:*.´+°.•*/

    /**
     * @notice Initializes a SingletonPaymaster instance.
     * @param _entryPoint The entryPoint address.
     * @param _owner The initial contract owner.
     */
    constructor(
        address _entryPoint,
        address _owner,
        address[] memory _signers
    ) BasePaymaster(_entryPoint, _owner) MultiSigner(_signers) {}

    /*´:°•.°+.*•´.*:˚.°*.˚•´.°:°•.°•.*•´.*:˚.°*.˚•´.°:°•.°+.*•´.*:*/
    /*                      ADMIN FUNCTIONS                       */
    /*.•°:°.´+˚.*°.˚:*.´•*.+°.•°:´*.´•*.•°.•°:°.´:•˚°.*°.˚:*.´+°.•*/

    /*´:°•.°+.*•´.*:˚.°*.˚•´.°:°•.°•.*•´.*:˚.°*.˚•´.°:°•.°+.*•´.*:*/
    /*                      INTERNAL HELPERS                      */
    /*.•°:°.´+˚.*°.˚:*.´•*.+°.•°:´*.´•*.•°.•°:°.´:•˚°.*°.˚:*.´+°.•*/

    /**
     * @notice Parses the userOperation's paymasterAndData field and returns the paymaster mode and encoded paymaster configuration bytes.
     * @dev _paymasterDataOffset should have value 20 for V6 and 52 for V7.
     * @param _paymasterAndData The paymasterAndData to parse.
     * @param _paymasterDataOffset The paymasterData offset in paymasterAndData.
     * @return mode The paymaster mode.
     * @return paymasterConfig The paymaster config bytes.
     */
    function _parsePaymasterAndData(
        bytes calldata _paymasterAndData,
        uint256 _paymasterDataOffset
    ) internal pure returns (uint8, bytes calldata) {
        if (_paymasterAndData.length < _paymasterDataOffset + 1) {
            revert PaymasterAndDataLengthInvalid();
        }

        uint8 mode = uint8(
            bytes1(
                _paymasterAndData[_paymasterDataOffset:_paymasterDataOffset + 1]
            )
        );
        bytes
            calldata paymasterConfig = _paymasterAndData[_paymasterDataOffset +
                1:];

        return (mode, paymasterConfig);
    }

    /**
     * @notice Parses the paymaster configuration when used in ERC-20 mode.
     * @param _paymasterConfig The paymaster configuration in bytes.
     * @return ERC20PaymasterData The parsed paymaster configuration values.
     */
    function _parseErc20Config(
        bytes calldata _paymasterConfig
    ) internal pure returns (ERC20PaymasterData memory) {
        if (_paymasterConfig.length < ERC20_PAYMASTER_DATA_LENGTH) {
            revert PaymasterConfigLengthInvalid();
        }

        uint48 validUntil = uint48(bytes6(_paymasterConfig[0:6]));
        uint48 validAfter = uint48(bytes6(_paymasterConfig[6:12]));
        address token = address(bytes20(_paymasterConfig[12:32]));
        uint256 feeAmount = uint256(bytes32(_paymasterConfig[32:64]));
        bytes calldata signature = _paymasterConfig[64:];

        if (token == address(0)) {
            revert TokenAddressInvalid();
        }

        if (signature.length != 64 && signature.length != 65) {
            revert PaymasterSignatureLengthInvalid();
        }

        ERC20PaymasterData memory config = ERC20PaymasterData({
            validUntil: validUntil,
            validAfter: validAfter,
            token: token,
            feeAmount: feeAmount,
            signature: signature
        });

        return config;
    }

    /**
     * @notice Parses the paymaster configuration when used in sponsoring mode.
     * @param _paymasterConfig The paymaster configuration in bytes.
     * @return validUntil The timestamp until which the sponsorship is valid.
     * @return validAfter The timestamp after which the sponsorship is valid.
     * @return signature The signature over the hashed sponsorship fields.
     * @dev The function reverts if the configuration length is invalid or if the signature length is not 64 or 65 bytes.
     */
    function _parseSponsoringConfig(
        bytes calldata _paymasterConfig
    ) internal pure returns (uint48, uint48, bytes calldata) {
        if (_paymasterConfig.length < SPONSORING_PAYMASTER_DATA_LENGTH) {
            revert PaymasterConfigLengthInvalid();
        }

        uint48 validUntil = uint48(bytes6(_paymasterConfig[0:6]));
        uint48 validAfter = uint48(bytes6(_paymasterConfig[6:12]));
        bytes calldata signature = _paymasterConfig[12:];

        if (signature.length != 64 && signature.length != 65) {
            revert PaymasterSignatureLengthInvalid();
        }

        return (validUntil, validAfter, signature);
    }

    /**
     * @notice Helper function to encode the postOp context data for V6 userOperations.
     * @param _userOp The userOperation.
     * @param _feeAmount The fee amount in ERC-20 token.
     * @param _userOpHash The userOperation hash.
     * @return bytes memory The encoded context.
     */
    function _createPostOpContext(
        UserOperation calldata _userOp,
        address _token,
        uint256 _feeAmount,
        bytes32 _userOpHash
    ) internal pure returns (bytes memory) {
        return
            abi.encode(
                ERC20PostOpContext({
                    sender: _userOp.sender,
                    token: _token,
                    feeAmount: _feeAmount,
                    userOpHash: _userOpHash
                })
            );
    }

    /**
     * @notice Helper function to encode the postOp context data for V7 userOperations.
     * @param _userOp The userOperation.
     * @param _feeAmount The fee amount in ERC-20 token.
     * @param _userOpHash The userOperation hash.
     * @return bytes memory The encoded context.
     */
    function _createPostOpContext(
        PackedUserOperation calldata _userOp,
        address _token,
        uint256 _feeAmount,
        bytes32 _userOpHash
    ) internal pure returns (bytes memory) {
        return
            abi.encode(
                ERC20PostOpContext({
                    sender: _userOp.sender,
                    token: _token,
                    feeAmount: _feeAmount,
                    userOpHash: _userOpHash
                })
            );
    }

    function _parsePostOpContext(
        bytes calldata _context
    ) internal pure returns (address, address, uint256, bytes32) {
        ERC20PostOpContext memory ctx = abi.decode(
            _context,
            (ERC20PostOpContext)
        );

        return (ctx.sender, ctx.token, ctx.feeAmount, ctx.userOpHash);
    }
}
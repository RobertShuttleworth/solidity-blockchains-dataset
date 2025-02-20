// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

import { Initializable } from "./lib_openzeppelin-contracts-upgradeable_contracts_proxy_utils_Initializable.sol";
import { AccessControlEnumerableUpgradeable } from "./lib_openzeppelin-contracts-upgradeable_contracts_access_extensions_AccessControlEnumerableUpgradeable.sol";
import { EIP712Upgradeable } from "./lib_openzeppelin-contracts-upgradeable_contracts_utils_cryptography_EIP712Upgradeable.sol";
import { ECDSA } from "./lib_openzeppelin-contracts-upgradeable_lib_openzeppelin-contracts_contracts_utils_cryptography_ECDSA.sol";

import { Roles } from "./src_constants_RoleConstants.sol";
import { Types } from "./src_libraries_Types.sol";
import { Types } from "./src_libraries_Types.sol";
import { Types } from "./src_libraries_Types.sol";
import { Types } from "./src_libraries_Types.sol";
import { Types } from "./src_libraries_Types.sol";
import { Types } from "./src_libraries_Types.sol";
import { ExceedsDeadline, InvalidSignature, InvalidZeroInput, NotAuthorized, NotEnoughSignatures } from "./src_errors_Errors.sol";

/// @title SignatureVerifierUpgradeable
/// @notice A contract for verifying signatures with upgradeable functionality
/// @dev Implements EIP-712 for secure signature verification
contract SignatureVerifierUpgradeable is Initializable, AccessControlEnumerableUpgradeable, EIP712Upgradeable {
    /// @notice Emitted when the signature threshold is updated
    /// @param threshold The new threshold value
    event ThresholdUpdated(uint256 threshold);

    /// @dev The minimum number of valid signatures required
    uint256 internal _threshold;

    /// @notice Initializes the contract
    /// @dev Should be called only once when the contract is deployed
    /// @param name_ The name of the signing domain
    /// @param version_ The current version of the signing domain
    /// @param threshold_ The initial threshold for required signatures
    /// @param signers_ The initial set of authorized signers
    function __SignatureVerifier_init(
        string memory name_,
        string memory version_,
        uint256 threshold_,
        address[] calldata signers_
    )
        internal
        onlyInitializing
    {
        __EIP712_init(name_, version_);
        __SignatureVerifier_init_unchained(threshold_, signers_);
    }

    /// @notice Initializes the contract (continued)
    /// @dev Internal function to be called from __SignatureVerifier_init
    /// @param threshold_ The initial threshold for required signatures
    /// @param signers_ The initial set of authorized signers
    function __SignatureVerifier_init_unchained(
        uint256 threshold_,
        address[] calldata signers_
    )
        internal
        onlyInitializing
    {
        _threshold = threshold_;
        for (uint256 i; i < signers_.length; i++) {
            _grantRole(Roles.SIGNER_ROLE, signers_[i]);
        }
    }

    /// @notice Sets the threshold for required signatures
    /// @dev Can only be called by an account with the OPERATOR_ROLE
    /// @param threshold_ New threshold value
    function setThreshold(uint256 threshold_) public onlyRole(Roles.OPERATOR_ROLE) {
        if (threshold_ == 0) revert InvalidZeroInput();

        _threshold = threshold_;
        emit ThresholdUpdated(threshold_);
    }

    /// @notice Validates if the given deadline has not passed
    /// @dev Reverts if the deadline is in the past
    /// @param deadline_ The timestamp to check against
    function _validateDeadline(uint256 deadline_) internal view {
        if (deadline_ < block.timestamp) {
            revert ExceedsDeadline();
        }
    }

    /// @notice Verifies a set of signatures against a given hash
    /// @dev Checks for enough signatures, duplicate signatures, and authorized signers
    /// @param hash_ The hash of the data that was signed
    /// @param signs_ An array of signatures to verify
    function _verifySignatures(bytes32 hash_, Types.Signature[] calldata signs_) internal view {
        uint256 length = signs_.length;

        if (_threshold == 0) revert InvalidZeroInput();

        if (length < _threshold) revert NotEnoughSignatures();

        address recoveredAddress;
        address lastAddress;
        bytes32 digest = _hashTypedDataV4(hash_);

        for (uint256 i; i < length;) {
            (recoveredAddress,,) = ECDSA.tryRecover(digest, signs_[i].v, signs_[i].r, signs_[i].s);

            if (recoveredAddress != address(0) && recoveredAddress <= lastAddress) revert InvalidSignature();

            if (!hasRole(Roles.SIGNER_ROLE, recoveredAddress)) revert NotAuthorized();

            lastAddress = recoveredAddress;

            unchecked {
                ++i;
            }
        }
    }

    function threshold() external view returns (uint256) {
        return _threshold;
    }

    function domainSeparator() external view returns (bytes32) {
        return _domainSeparatorV4();
    }

    uint256[49] private __gap;
}
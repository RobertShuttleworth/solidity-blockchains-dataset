// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

import "./lib_openzeppelin-contracts_contracts_utils_cryptography_ECDSA.sol";
import {SignatureVerification} from "./src_library_SignatureVerification.sol";
import {ISecurity} from "./src_interfaces_ISecurity.sol";
import "./src_storage_PoolPartyPositionManagerStorage.sol";

/**
 * @title Security Contract
 * @notice This contract is used to manage security features and protections for the PoolPartyPositionManager.
 * It handles the enabling and disabling of various security protections, setting the root for the operators whitelist,
 * and managing the signer security address. It also includes a modifier for performing security checks on transactions.
 */
abstract contract Security is ISecurity, PoolPartyPositionManagerStorage {
    using ECDSA for bytes32;
    using SignatureVerification for bytes;

    modifier securityCheck(SecurityProtectionParams calldata _params) {
        _checkSecurity(_params);
        _;
    }

    /// @inheritdoc ISecurity
    // aderyn-ignore-next-line(state-variable-changes-without-events)
    function setRootForOperatorsWhitelist(bytes32 _root)
        external
        whenNotDestroyed
        onlyRole(DEFAULT_ADMIN_ROLE) // aderyn-ignore(centralization-risk)
    {
        s.rootForOperatorsWhitelist = _root;
    }

    /// @inheritdoc ISecurity
    // aderyn-ignore-next-line(state-variable-changes-without-events)
    function setSignerSecurityAddress(address _signerSecurityAddress)
        external
        onlyRole(Constants.UPGRADER_ROLE) // aderyn-ignore(centralization-risk)
    {
        s.signerSecurityAddress = _signerSecurityAddress;
    }

    /// @inheritdoc ISecurity
    // aderyn-ignore-next-line(state-variable-changes-without-events)
    function disableCube3Protection()
        external
        onlyRole(Constants.UPGRADER_ROLE) // aderyn-ignore(centralization-risk)
    {
        require(!s.cube3ProtectionDisabled, Errors.Cube3ProtectionNotEnabled());
        s.cube3ProtectionDisabled = true;
    }

    /// @inheritdoc ISecurity
    // aderyn-ignore-next-line(state-variable-changes-without-events)
    function enableCube3Protection()
        external
        onlyRole(Constants.UPGRADER_ROLE) // aderyn-ignore(centralization-risk)
    {
        require(s.cube3ProtectionDisabled, Errors.Cube3ProtectionEnabled());
        s.cube3ProtectionDisabled = false;
    }

    /// @inheritdoc ISecurity
    // aderyn-ignore-next-line(state-variable-changes-without-events)
    function disableProtection()
        external
        onlyRole(Constants.UPGRADER_ROLE) // aderyn-ignore(centralization-risk)
    {
        require(!s.protectionDisabled, Errors.ProtectionNotEnabled());
        s.protectionDisabled = true;
    }

    /// @inheritdoc ISecurity
    // aderyn-ignore-next-line(state-variable-changes-without-events)
    function enableProtection()
        external
        onlyRole(Constants.UPGRADER_ROLE) // aderyn-ignore(centralization-risk)
    {
        require(s.protectionDisabled, Errors.ProtectionEnabled());
        s.protectionDisabled = false;
    }

    /**
     * @notice Checks the security protection parameters.
     * @param _params The security protection parameters.
     */
    // aderyn-ignore-next-line(state-variable-changes-without-events)
    function _checkSecurity(SecurityProtectionParams calldata _params) internal {
        if (s.protectionDisabled && s.cube3ProtectionDisabled) {
            return;
        }
        if (!s.cube3ProtectionDisabled) {
            _assertProtectWhenConnected(_params.payload);
        } else {
            // slither-disable-next-line timestamp
            require(block.timestamp <= _params.sigDeadline, Errors.SignatureExpired());
            bytes32 digest = _hashTypedDataV4(
                keccak256(
                    abi.encode(
                        keccak256("Security(bytes32 payloadHash,uint256 deadline)"),
                        _params.payloadHash,
                        _params.sigDeadline
                    )
                )
            );
            require(!s.signatures[digest][_params.signature], Errors.SignatureAlreadyUsed());
            s.signatures[digest][_params.signature] = true;
            _params.signature.verify(digest, s.signerSecurityAddress);
        }
    }
}
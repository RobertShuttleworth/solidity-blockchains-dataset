// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

interface ISecurityStructs {
    struct SecurityProtectionParams {
        bytes32 payloadHash;
        bytes signature;
        bytes payload;
        uint256 sigDeadline;
    }
}

interface ISecurity is ISecurityStructs {
    /// @notice Sets the root for the operators whitelist
    function setRootForOperatorsWhitelist(bytes32 _root) external;

    /// @notice Sets the signer security address
    function setSignerSecurityAddress(address _signerSecurityAddress) external;

    /// @notice Disables the protection for the cube3
    function disableCube3Protection() external;

    /// @notice Enables the protection for the cube3
    function enableCube3Protection() external;

    /// @notice Disables the protection for the manager
    function disableProtection() external;

    /// @notice Enables the protection for the manager
    function enableProtection() external;
}
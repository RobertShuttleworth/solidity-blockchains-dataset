// SPDX-License-Identifier: GPL-3.0-or-later

pragma solidity 0.7.6;
pragma abicoder v2;

/// @notice A forwarder interface
interface IForwarder {

    /// @dev forward validator request
    struct ForwardRequest {
        address validator;
        address targetAddress;
        bytes data;
        address paymentToken;
        uint256 paymentFees;
        uint256 tokenGasPrice;
        uint256 validTo;
        uint256 nonce;
    }

    /// @notice Forwards the request, by validating the signatory.
    ///         Uses payment fees to cover for the gas fees
    /// @param  request Forwarding request
    /// @param  validatorSignature signature containing a valid sign from a validator
    function executeCall(
            ForwardRequest calldata request,
            bytes calldata validatorSignature
    )
    external
    payable;
}
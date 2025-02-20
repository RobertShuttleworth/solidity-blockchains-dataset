// SPDX-License-Identifier: MIT
pragma solidity >=0.8.19 < 0.9.0;

/// @title ICube3RouterMinimal
/// @notice Minimal interface for interacting with the CUBE3 Router.
/// @dev This interface omits all function signatures for functions that are not called
/// directly by this integration contract.
interface ICube3RouterMinimal {
    /// @notice Initiates the registration of a new integration contract with the CUBE3 protocol.
    ///
    /// @dev Emits {IntegrationAdminTransferred} and {IntegrationRegistrationStatusUpdated} events.
    ///
    /// Notes:
    /// - Called by integration contract from inside its constructor, thus the integration contract is `msg.sender`.
    /// - We cannot restrict who what kind of account calls this function, including EOAs. However, an integration has
    /// no access to the protocol until {registerIntegrationWithCube3} is called by the integration's admin, for
    /// which a registrarSignature is required and must be signed by the integration's signing authority provided by
    /// CUBE3.
    /// - Only a contract account who initiated registration can complete registration via codesize check.
    ///
    /// Requirements:
    /// - The `initialAdmin` cannot be the zero address.
    /// - The integration, as the `msg.sender`, must not have previously registered with the protocol.
    ///
    /// @param initialAdmin The account to assign admin privileges to for the integration contract.
    ///
    /// @return The PRE_REGISTRATION_SUCCEEDED hash, a unique representation of a successful pre-registration.
    function initiateIntegrationRegistration(address initialAdmin) external returns (bytes32);

    /// @notice Routes the top-level calldata to the Security Module using data
    /// embedded in the routing bitmap.
    ///
    /// @dev If events are emitted, they're done so by the Security Module being utilized.
    ///
    /// Notes:
    /// - Acts like an assertion.  Will revert on any error or failure to meet the
    /// conditions laid out by the security module.
    /// - Will bypass the security modules under the following conditions, checked
    /// sequentially:
    ///     - Function protection for the provided selector is disabled.
    ///     - The integration's registration status is revoked.
    ///     - The Protocol is paused.
    /// - Only contracts can be registered as integrations, so checking against UNREGISTERED
    /// status is redundant.
    /// - No Ether is transferred to the router, so the function is non-payable.
    /// - If the module function call reverts, the revert data will be relayed to the integration.
    ///
    /// Requirements:
    /// - The last word of the `integrationCalldata` is a valid routing bitmap.
    /// - The module identified in the routing bitmap must be installed.
    /// - The call to the Security Module must succeed.
    ///
    /// @param integrationMsgSender the `msg.sender` of the top-level call.
    /// @param integrationMsgValue The `msg.value` of the top-level call.
    /// @param integrationCalldata The `msg.data` of the top-level call, which includes the
    /// CUBE3 Payload.
    ///
    /// @return The PROCEED_WITH_CALL magic value if the call succeeds.
    function routeToModule(
        address integrationMsgSender,
        uint256 integrationMsgValue,
        bytes calldata integrationCalldata
    ) external returns (bytes32);
}
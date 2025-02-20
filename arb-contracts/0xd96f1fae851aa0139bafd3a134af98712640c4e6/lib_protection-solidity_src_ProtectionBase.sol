// SPDX-License-Identifier: MIT
pragma solidity >=0.8.19 < 0.9.0;

import {ICube3RouterMinimal} from "./lib_protection-solidity_src_interfaces_ICube3RouterMinimal.sol";

/// @title ProtectionBase
/// @notice Provides all functionality for connecting to the CUBE3 protocol and adding function-level protection
/// to functions in the derived contract.
/// @dev Function visibility is set to `internal` instead of `private` to allow for testing via
/// a harness contract.
abstract contract ProtectionBase {
    /////////////////////////////////////////////////////////////////////////
    //                             CONSTANTS                               //
    /////////////////////////////////////////////////////////////////////////

    // Expected hashed return value from the router indicating the call is safe to proceed.
    bytes32 private constant PROCEED_WITH_CALL =
        keccak256("CUBE3_PROCEED_WITH_CALL");

    // Expected hashed return value from the router indicating the pre-registration and setting of the admin succeeded.
    bytes32 private constant PRE_REGISTRATION_SUCCEEDED =
        keccak256("CUBE3_PRE_REGISTRATION_SUCCEEDED");

    // ERC7201 namespace derivation for storage layout.
    // keccak256(abi.encode(uint256(keccak256("cube3.storage")) - 1)) & ~bytes32(uint256(0xff));
    bytes32 private constant CUBE3_PROTECTED_STORAGE_LOCATION =
        0xd26911dcaedb68473d1e75486a92f0a8e6ef3479c0c1c4d6684d3e2888b6b600;

    /////////////////////////////////////////////////////////////////////////
    //                             EVENTS                                  //
    /////////////////////////////////////////////////////////////////////////

    /// @notice Emitted when the connection to the CUBE3 protocol is updated.
    /// @param connectionEstablished When True, means the connection to the Protocol is established
    /// and transaction data will be forwarded to the router and function protection status will be checked.
    event Cube3ProtocolConnectionUpdated(bool connectionEstablished);

    /// @notice Emitted when this integration is deployed.
    /// @param integrationAdmin The account designated as the account's admin account on the router.
    /// This account can complete the integration registration and update function protection status.
    /// @param enabledByDefault Whether the Integration is connected to the Protocol by default.
    event Cube3IntegrationDeployed(
        address indexed integrationAdmin,
        bool enabledByDefault
    );

    /////////////////////////////////////////////////////////////////////////
    //                             ERRORS                                  //
    /////////////////////////////////////////////////////////////////////////

    /// @notice Thrown when the router address is set to the zero address.
    error Cube3Protection_InvalidRouter();

    /// @notice Thrown when the integration admin address is set to the zero address.
    error Cube3Protection_InvalidAdmin();

    /// @notice Thrown when the CUBE3 Router returns an invalid value.
    error Cube3Protection_InvalidRouterReturn();

    /// @notice Thrown when the CUBE3 Payload provided is an invalid size.
    error Cube3Protection_InvalidPayloadSize();

    /// @notice Thrown when pre-registration with the CUBE3 Router fails.
    error Cube3Protection_PreRegistrationFailed();

    /////////////////////////////////////////////////////////////////////////
    //                             STORAGE                                 //
    /////////////////////////////////////////////////////////////////////////

    /// @custom:storage-location erc7201:cube3.storage
    /// @param router The address of the CUBE3 router contract. Security modules are accessed via the router.
    /// @param shouldCheckFnProtection Determines whether to establish a connection to the protocol.  If set
    /// to true, a call will be made to the router where the protection status of the function will be evaluated
    /// and the call will be forwarded to the appropriate security module if protection is enabled.
    struct ProtectedStorage {
        address router;
        bool shouldCheckFnProtection;
    }

    /////////////////////////////////////////////////////////////////////////
    //                             MODIFIERS                               //
    /////////////////////////////////////////////////////////////////////////

    /// @notice Adds function-level protection to the function.
    /// @dev Adding this modifier to a function adds the ability to apply function-level protection to the function.
    /// If the connection to the protocol is enabled via {ProtectedStorage.shouldCheckFnProtection}, all calls to
    /// functions decorated with this modifier are forwarded to the CUBE3 Router. If utilized, the protocol will forward
    /// the calldata to the module designated in the payload's routing bitmap.
    /// @dev Will revert if the payload fails any security checks.
    modifier cube3Protected(bytes calldata cube3Payload) {
        // If connected to the CUBE3 protocol, the function's protection status will
        // be checked via an external call to the router and forwarded to the relevenat
        // security module if enabled.
        _assertProtectWhenConnected(cube3Payload);
        _;
    }

    /// @notice Indicates whether this integration contract is connected to the CUBE3 protocol.
    /// @dev When this function returns true, this integration will route calls to the CUBE3 protocol when
    /// the `cube3Protected` modifier is applied to a function. When false, the function will execute as normal.
    /// @return The connection status to the CUBE3 protocol.
    function connectedToCUBE3() public view returns (bool) {
        return _cube3Storage().shouldCheckFnProtection;
    }

    /////////////////////////////////////////////////////////////////////////
    //                             INITIALIZATION                          //
    /////////////////////////////////////////////////////////////////////////

    /// @notice Initializes the CUBE3 Protection abstraction.
    /// @dev Called by the derived contract's initializer or constructor to set the router address and integration
    /// admin.  The call will revert if the correct router address is not supplied due to check on the returned value.
    /// Makes an external call to the Router to initiate the registration of this integration.
    /// @param router The address of the CUBE3 Router proxy contract.
    /// @param integrationAdmin The address of the integration admin. Set and managed by the CUBE3 Router.
    /// @param enabledByDefault If set to true, the connection to the CUBE3 core protocol will be established by
    /// default.
    function _baseInitProtection(
        address router,
        address integrationAdmin,
        bool enabledByDefault
    ) internal {
        // Checks: the router address is provided.
        if (router == address(0)) {
            revert Cube3Protection_InvalidRouter();
        }

        // Checks: the integration admin is provided.
        if (integrationAdmin == address(0)) {
            revert Cube3Protection_InvalidAdmin();
        }

        // Set the router address.
        _cube3Storage().router = router;

        // Enable/disable the connection to the CUBE3 core protocol.
        _updateShouldUseProtocol(enabledByDefault);

        // Interactions: pre-register this integration with the router and set this contract's admin address. This call
        // serves the dual purpose of validating that the correct router address was passed in the constructor and
        // setting this integration's admin account on the protocol.
        _assertPreRegistrationSucceeds(router, integrationAdmin);

        // Log: the creation of the integration and the default config.
        emit Cube3IntegrationDeployed(integrationAdmin, enabledByDefault);
    }

    /////////////////////////////////////////////////////////////////////////
    //                             PROTECTION LOGIC                        //
    /////////////////////////////////////////////////////////////////////////

    /// @dev Checks the connection status to the CUBE3 protocol and forwards the calldata to the protocol
    /// if connected.
    /// @dev Can be called at the top of the derived contract's external functions directly intead of the modifier to
    /// reduce codesize from inlining the modifier multiple times.
    /// @dev The `cube3Payload` argument is not used as the data is extraded from calldata, but is kept to remind the
    /// developer to pass the payload as an argument to the enclosing function.
    function _assertProtectWhenConnected(bytes calldata cube3Payload) internal {
        // bypasses compiler warnings for unused fn arguments
        (cube3Payload);
        // Checks: the payload should be forwared to the CUBE3 protocol.
        if (connectedToCUBE3()) {
            // Interactions: forward the calldata, including the payload, along with the call context, to the CUBE3
            // protocol where it will be routed to the desired security module.
            _assertShouldProceedAndCall();
        }
    }

    /// @notice Determines whether the connection to the CUBE3 protocol is enabled, transmits the calldata
    /// including the payload to the protocol, and asserts that the call should proceed.
    /// @dev The payload is not explicitly passed to the router as it's implicitly encoded in the msg.data
    /// used to construct the calldata for the `routeToModule` call. Will return early if function protection
    /// is disabled for the top-level function call.
    function _assertShouldProceedAndCall() internal {
        try
            ICube3RouterMinimal(_cube3Storage().router).routeToModule(
                msg.sender,
                _getMsgValue(),
                msg.data
            )
        returns (bytes32 result) {
            // Checks: the call succeeded with the expected return value.
            if (result != PROCEED_WITH_CALL) {
                revert Cube3Protection_InvalidRouterReturn();
            }
            return;
        } catch (bytes memory revertData) {
            // Bubble up the revert data to capture the original error from the protocol.
            assembly {
                revert(add(revertData, 0x20), mload(revertData))
            }
        }
    }

    /// @notice Ensures the correct `router` address is set and initiates the registration of this integration,
    /// while simultaneously setting this integration's admin account on the protocol.
    /// @dev Will revert if the correct router address is not supplied or the admin account is the zero address.
    /// @param router The address of the CUBE3 Router proxy contract.
    /// @param admin The admin account for this contract from the CUBE3 Protocol's perspective.
    function _assertPreRegistrationSucceeds(
        address router,
        address admin
    ) internal {
        try
            ICube3RouterMinimal(router).initiateIntegrationRegistration(admin)
        returns (bytes32 result) {
            // Checks: the call succeeded with the expected return value.
            if (result != PRE_REGISTRATION_SUCCEEDED) {
                revert Cube3Protection_PreRegistrationFailed();
            }
            return;
        } catch (bytes memory revertData) {
            // Bubble up the revert data to capture the original error from the protocol.
            assembly {
                revert(add(revertData, 0x20), mload(revertData))
            }
        }
    }

    /////////////////////////////////////////////////////////////////////////
    //                              STORAGE                                //
    /////////////////////////////////////////////////////////////////////////

    /// @notice Determins whether a call should be made to the CUBE3 Protocol to check the protection status of
    /// of function of the top-level call.
    /// @dev WARNING: This MUST only be called within an external/public with some form of access control.
    /// If the derived contract has no access control, this function should not be exposed and the connection
    /// to the protocol is locked at the time of deployment.
    function _updateShouldUseProtocol(bool connectToProtocol) internal {
        _cube3Storage().shouldCheckFnProtection = connectToProtocol;
        emit Cube3ProtocolConnectionUpdated(connectToProtocol);
    }

    /// @notice Returns a pointer to the contract's storage.
    /// @dev Convenience function that returns a storage pointer to CUBE3 protection storage.
    function _cube3Storage()
        internal
        pure
        returns (ProtectedStorage storage cube3Storage)
    {
        assembly {
            cube3Storage.slot := CUBE3_PROTECTED_STORAGE_LOCATION
        }
    }

    /// @notice Helper function to retrieve the call's `msg.value`.
    /// @dev A non-payable function cannot read msg.value in the {cube3Protected} modifier.
    /// Will not clash with `_msgValue` in the event that the derived contract inherits {Context}.
    function _getMsgValue() internal view returns (uint256) {
        return msg.value;
    }
}
// SPDX-License-Identifier: MIT
pragma solidity >=0.8.19 < 0.9.0;

import { ICube3RouterMinimal } from "./lib_protection-solidity_src_interfaces_ICube3RouterMinimal.sol";
import { ProtectionBase } from "./lib_protection-solidity_src_ProtectionBase.sol";

/// @title Cube3ProtectionUpgradeable
/// @notice Upgradeable implementation of the ProtectionBase contract. This contract enables access for the
/// derived contract to the CUBE3 Core Protocol and adds function-level protection functionality to any external
/// functions in the derived contract through the {cube3Protected} modifier.
///
/// Notes:
/// - Implements the abstract {ProtectionBase} contract, which utilizes ERC7201 namespaces for storage layout to
/// prevent storage collisions across upgrades.
/// - The initialize functions should be called in the derived contract's initializer.
/// - See {ProtectionBase} for implementation details.
abstract contract Cube3ProtectionUpgradeable is ProtectionBase {
    /// @notice Initialized the CUBE3 Protection abstraction.
    /// @dev The `integrationAdmin` is the account granted elevated privileges on the CUBE3 Router. The Integration's
    /// Admin is the account that will be permissioned to complete this integration's registration with the protocol and
    /// can enable/disable protection for the functions decorated with the {cube3Protected} modifier.
    /// MUST be called in the derived contract's initializer.
    /// @param router The address of the CUBE3 Router's proxy contract.
    /// @param integrationAdmin The account to grant elevated privileges to on the CUBE3 Router.
    /// @param enabledByDefault If set to true, the protection status for each function decorated with the
    /// {cube3Protected} modifier will be checked via the Router by default.
    function __Cube3ProtectionUpgradeable_init(
        address router,
        address integrationAdmin,
        bool enabledByDefault
    )
        internal
    {
        __Cube3ProtectionUpgradeable_init_unchained(router, integrationAdmin, enabledByDefault);
    }

    /// @dev Follows the pattern established by OpenZeppelin for dealing with multiple inheritance.
    /// See {__Cube3ProtectionUpgradeable_init} for argument details.
    function __Cube3ProtectionUpgradeable_init_unchained(
        address _router,
        address _integrationAdmin,
        bool _enabledByDefault
    )
        private
    {
        _baseInitProtection(_router, _integrationAdmin, _enabledByDefault);
    }
}
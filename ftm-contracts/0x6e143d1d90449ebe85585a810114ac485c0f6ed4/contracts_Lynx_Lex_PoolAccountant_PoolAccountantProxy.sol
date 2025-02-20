// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.24;

import "./contracts_AdministrationContracts_AcceptableRegistryImplementationClaimableAdmin.sol";
import "./contracts_Lynx_Lex_LexPool_LexPoolStorage.sol";

/**
 * @title LexPoolProxy
 * @dev Used as the upgradable lex pool of the Lynx platform
 */
contract PoolAccountantProxy is AcceptableRegistryImplementationClaimableAdmin {
  constructor(
    address _registry
  )
    AcceptableRegistryImplementationClaimableAdmin(_registry, "PoolAccountant")
  {}
}
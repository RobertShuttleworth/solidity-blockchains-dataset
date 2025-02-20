// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.0;

import {IPolicyPool} from "./ensuro_core_contracts_interfaces_IPolicyPool.sol";
import {IERC165} from "./openzeppelin_contracts_utils_introspection_IERC165.sol";

/**
 * @title IPolicyPoolComponent interface
 * @dev Interface for Contracts linked (owned) by a PolicyPool. Useful to avoid cyclic dependencies
 * @author Ensuro
 */
interface IPolicyPoolComponent is IERC165 {
  /**
   * @dev Returns the address of the PolicyPool (see {PolicyPool}) where this component belongs.
   */
  function policyPool() external view returns (IPolicyPool);
}
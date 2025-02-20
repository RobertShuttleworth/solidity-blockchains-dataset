// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "./openzeppelin_contracts_access_manager_AccessManager.sol";

/**
 * @title MajoraAccessManager
 * @author Majora Development Association
 * @notice Manages access and roles for the Majora platform.
 * @dev Extends OpenZeppelin's AccessManager to include specific roles and functionalities for the Majora platform.
 */
contract MajoraAccessManager is AccessManager {

    uint64 public constant UPGRADER_ROLE = 1;
    uint64 public constant MOPT_TAKER_ROLE = 2;
    uint64 public constant OPERATOR_ROLE = 3;
    uint64 public constant OPERATION_GUARDIAN_ROLE = 4;
    uint64 public constant ERC2771_RELAYER_ROLE = 5;
    uint64 public constant CROSSCHAIN_RELAYER_ROLE = 6;
    uint64 public constant FEE_MANAGER_ROLE = 7;
    uint64 public constant INTEGRATOR_ROLE = 8;
    uint64 public constant CREATOR_ROLE = 9;

    constructor(address _initialAdmin) AccessManager(_initialAdmin) {}
}
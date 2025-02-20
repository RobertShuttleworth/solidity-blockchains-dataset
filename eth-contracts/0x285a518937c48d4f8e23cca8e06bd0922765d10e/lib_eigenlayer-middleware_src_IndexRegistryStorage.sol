// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.12;

import {Initializable} from "./lib_eigenlayer-contracts_lib_openzeppelin-contracts-upgradeable_contracts_proxy_utils_Initializable.sol";

import {IRegistryCoordinator} from "./lib_eigenlayer-middleware_src_interfaces_IRegistryCoordinator.sol";
import {IIndexRegistry} from "./lib_eigenlayer-middleware_src_interfaces_IIndexRegistry.sol";

/**
 * @title Storage variables for the `IndexRegistry` contract.
 * @author Layr Labs, Inc.
 * @notice This storage contract is separate from the logic to simplify the upgrade process.
 */
abstract contract IndexRegistryStorage is Initializable, IIndexRegistry {

    /// @notice The value that is returned when an operator does not exist at an index at a certain block
    bytes32 public constant OPERATOR_DOES_NOT_EXIST_ID = bytes32(0);

    /// @notice The RegistryCoordinator contract for this middleware
    address public immutable registryCoordinator;

    /// @notice maps quorumNumber => operator id => current operatorIndex
    /// NOTE: This mapping is NOT updated when an operator is deregistered,
    /// so it's possible that an index retrieved from this mapping is inaccurate.
    /// If you're querying for an operator that might be deregistered, ALWAYS 
    /// check this index against the latest `_operatorIndexHistory` entry
    mapping(uint8 => mapping(bytes32 => uint32)) public currentOperatorIndex;
    /// @notice maps quorumNumber => operatorIndex => historical operator ids at that index
    mapping(uint8 => mapping(uint32 => OperatorUpdate[])) internal _operatorIndexHistory;
    /// @notice maps quorumNumber => historical number of unique registered operators
    mapping(uint8 => QuorumUpdate[]) internal _operatorCountHistory;

    constructor(
        IRegistryCoordinator _registryCoordinator
    ){
        registryCoordinator = address(_registryCoordinator);
        // disable initializers so that the implementation contract cannot be initialized
        _disableInitializers();
    }

    // storage gap for upgradeability
    uint256[47] private __GAP;
}
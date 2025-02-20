// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import "./openzeppelin_contracts_access_Ownable.sol";
import "./openzeppelin_contracts_token_ERC20_IERC20.sol";
import "./openzeppelin_contracts_proxy_Clones.sol";

import "./openzeppelin_contracts_access_manager_AccessManaged.sol";

import {IMajoraPositionManagerFactory} from "./contracts_interfaces_IMajoraPositionManagerFactory.sol";
import {IMajoraPositionManager} from "./contracts_interfaces_IMajoraPositionManager.sol";


/**
 * @title Majora Position Manager Factory
 * @author Majora Development Association
 * @dev Factory contract for creating and managing Majora Position Managers. It allows the deployment of new position managers, 
 * management of position manager types, and tracking of all position managers created through the factory.
 * The factory is also responsible for initializing position managers with the correct parameters upon creation.
 */
contract MajoraPositionManagerFactory is AccessManaged, IMajoraPositionManagerFactory {
    /// @notice Mapping from ID to PositionManagerType details
    mapping(bytes32 => PositionManagerType) private _positionManagerTypes;

    /// @notice Total number of position managers created
    uint256 public positionManagerLength;

    /// @notice Mapping from position manager ID to PositionManager details
    mapping(uint256 => PositionManager) public positionManagers;

    //// @notice Mapping from position manager address to whether it is a position manager
    mapping(address => bool) public isPositionManager;

    /// @notice Mapping from owner address to the index of their last owned position manager
    mapping(address => uint256) private ownedPositionManagerIndex;

    /// @notice Nested mapping from owner address to index to position manager ID, tracking all position managers owned by an address
    mapping(address => mapping(uint256 => uint256)) private ownedPositionManager;

    constructor(address _authority) AccessManaged(_authority) {} //@note UPDATE owner

    /**
     * @notice Deploys new position managers based on the specified types and initializes them with the provided parameters.
     * @dev This function creates new position managers, initializes them, and emits a NewPositionManager event for each.
     * @param _owner The owner of the new position managers.
     * @param _types An array of position manager types. Each type corresponds to a PositionManagerType struct.
     * @param _blockIndexes An array of block indexes for the position managers. Used during initialization.
     * @param _collaterals An array of collateral addresses for the position managers.
     * @param _borroweds An array of borrowed asset addresses for the position managers.
     * @param _params An array of bytes containing initialization parameters for each position manager.
     */
    function deployNewPositionManagers(
        bool _ownerIsMajoraVault,
        address _owner,
        bytes32[] memory _types,
        uint256[] memory _blockIndexes,
        address[] memory _collaterals,
        address[] memory _borroweds,
        bytes[] memory _params
    ) external {
        uint256 length = _types.length;
        for (uint256 i = 0; i < length; i++) {
            if (_positionManagerTypes[_types[i]].version == 0) revert InvalidPositionManagerType();

            uint256 pmLength = positionManagerLength;
            address proxy = Clones.clone(_positionManagerTypes[_types[i]].implementation);
            address aggregator = _positionManagerTypes[_types[i]].aggregator;
            emit NewPositionManager(pmLength, _owner, _ownerIsMajoraVault, _types[i], _collaterals[i], _borroweds[i], proxy, aggregator);

            IMajoraPositionManager(proxy).initialize(_ownerIsMajoraVault, _owner, _blockIndexes[i], _params[i]);

            positionManagers[pmLength] = PositionManager({owner: _owner, addr: proxy, pmType: _types[i], aggregator: aggregator});

            ownedPositionManager[_owner][ownedPositionManagerIndex[_owner]] = pmLength;
            ownedPositionManagerIndex[_owner] += 1;
            positionManagerLength += 1;

            isPositionManager[proxy] = true;
        }
    }

    function positionManagerTypes(bytes32 _id) external view returns (PositionManagerType memory) {
        // if (_positionManagerTypes[_id].version == 0) revert PositionManagerNotExists();
        return _positionManagerTypes[_id];
    }

    function addNewPositionManagerType(string memory name, address implementation, address aggregator) external restricted {

        bytes32 _id = keccak256(bytes(name));
        if (_positionManagerTypes[_id].version > 0) revert PositionManagerAlreadyExists();

        _positionManagerTypes[_id] = PositionManagerType({
            name: name,
            implementation: implementation,
            version: 1,
            aggregator: aggregator
        });

        emit NewPositionManagerType(_id, name, implementation, aggregator, 1);
    }

    function upgradePositionManagerType(bytes32 _id, address _implementation, address _aggregator) external restricted {
        _positionManagerTypes[_id].implementation = _implementation;
        _positionManagerTypes[_id].aggregator = _aggregator;
        _positionManagerTypes[_id].version += 1;
        emit PositionManagerTypeUpdated(_id, _implementation, _aggregator, _positionManagerTypes[_id].version);
    }

    function disablePositionManagerType(bytes32 _id) external restricted {
        _positionManagerTypes[_id].version = 0;
        emit PositionManagerTypeDisabled(_id);
    }

    function getOwnedPositionManagerBy(address owner) external view returns (address[] memory) {
        uint256 ownedPMIndexes = ownedPositionManagerIndex[owner];
        address[] memory pmAddresses = new address[](ownedPMIndexes);
        for (uint256 i = 0; i < ownedPMIndexes; i++) {
            pmAddresses[i] = positionManagers[ownedPositionManager[owner][i]].addr;
        }

        return pmAddresses;
    }
}
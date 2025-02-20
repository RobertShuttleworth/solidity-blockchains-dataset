// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.0;

/**
 * @title Majora Position Manager Factory interface
 * @author Majora Development Association
 */
interface IMajoraPositionManagerFactory {

    error PositionManagerNotExists();
    error PositionManagerAlreadyExists();
    
    /**
     * @dev Represents the type of a Position Manager, including its name, implementation address, info address, and version.
     * @param name The name of the Position Manager Type.
     * @param implementation The address of the implementation contract for this Position Manager Type.
     * @param info The address of the info contract associated with this Position Manager Type.
     * @param version The version number of this Position Manager Type.
     */
    struct PositionManagerType {
        string name;
        address implementation;
        address aggregator;
        uint256 version;
    }

    /**
     * @dev Represents a Position Manager, including its owner, address, info address, and type.
     * @param owner The address of the owner of the Position Manager.
     * @param addr The address of the Position Manager contract.
     * @param info The address of the info contract associated with this Position Manager.
     * @param pmType The type index of the Position Manager.
     */
    struct PositionManager {
        address owner;
        address addr;
        address aggregator;
        bytes32 pmType;
    }


    /**
     * @dev Emitted when a new Position Manager Type is added.
     * @param index The index of the new Position Manager Type.
     * @param name The name of the new Position Manager Type.
     * @param implementation The address of the implementation of the new Position Manager Type.
     * @param aggregator The address of the aggregator contract associated with the new Position Manager Type.
     * @param version The version of the new Position Manager Type.
     */
    event NewPositionManagerType(
        bytes32 index,
        string name,
        address implementation,
        address aggregator,
        uint256 version
    );

    /**
     * @dev Emitted when an existing Position Manager Type is updated.
     * @param index The index of the updated Position Manager Type.
     * @param implementation The new address of the implementation of the updated Position Manager Type.
     * @param aggregator The new address of the aggregator contract associated with the updated Position Manager Type.
     * @param version The new version of the updated Position Manager Type.
     */
    event PositionManagerTypeUpdated(
        bytes32 index,
        address implementation,
        address aggregator,
        uint256 version
    );

    /**
     * @dev Emitted when a Position Manager Type is disabled.
     * @param index The index of the disabled Position Manager Type.
     */
    event PositionManagerTypeDisabled(bytes32 index);

    /**
     * @dev Emitted when a new Position Manager is created.
     * @param index The index of the new Position Manager.
     * @param owner The address of the owner of the new Position Manager.
     * @param pmType The type of the new Position Manager.
     * @param collateral The address of the collateral token for the new Position Manager.
     * @param borrowed The address of the borrowed token for the new Position Manager.
     * @param addr The address of the new Position Manager.
     * @param aggregator The address of the info contract associated with the new Position Manager.
     */
    event NewPositionManager(
        uint256 index,
        address owner,
        bool ownerIsMajoraVault,
        bytes32 pmType,
        address collateral,
        address borrowed,
        address addr,
        address aggregator
    );

    /// @notice returned when the Position Manager Type is invalid.
    error InvalidPositionManagerType();
    /// @notice returned when the caller is not the owner of the Position Manager.
    error NotOwner();

    function isPositionManager(address _addr) external view returns (bool);

    function positionManagerTypes(bytes32 _index) external view returns (PositionManagerType memory);

    function positionManagerLength() external view returns (uint256);
    function positionManagers(uint256 _index) external view returns (
        address owner,
        address addr,
        address aggregator,
        bytes32 pmType
    );

    function deployNewPositionManagers(
        bool _ownerIsMajoraVault,
        address _owner,
        bytes32[] memory _types,
        uint256[] memory _blockIndexes,
        address[] memory _collaterals,
        address[] memory _borroweds,
        bytes[] memory _params
    ) external;

    function addNewPositionManagerType(string memory name, address implementation, address aggregator) external;
    function upgradePositionManagerType(bytes32 _id, address _implementation, address _aggregator) external;
    function disablePositionManagerType(bytes32 _id) external;
    function getOwnedPositionManagerBy(address owner) external view returns (address[] memory);
}
// SPDX-License-Identifier: AGPL-3.0
pragma solidity ^0.8.0;

interface IMajoraPositionManagerFactory {
    struct PositionManagerType {
        string name;
        address implementation;
        address info;
        uint256 version;
    }

    struct PositionManager {
        address owner;
        address addr;
        address info;
        uint256 pmType;
    }

    event NewPositionManagerType(
        uint256 index,
        string name,
        address implementation,
        address info,
        uint256 version
    );

    event PositionManagerTypeUpdated(
        uint256 index,
        address implementation,
        address info,
        uint256 version
    );

    event PositionManagerTypeDisabled(uint256 index);

    event NewPositionManager(
        uint256 index,
        address owner,
        uint256 pmType,
        address collateral,
        address borrowed,
        address addr,
        address info
    );

    error InvalidPositionManagerType();
    error NotOwner();

    function isPositionManager(address _addr) external view returns (bool);

    function positionManagerTypeLength() external view returns (uint256);
    function positionManagerTypes(uint256 _index) external view returns (
        string memory name,
        address implementation,
        address info,
        uint256 version
    );

    function positionManagerLength() external view returns (uint256);
    function positionManagers(uint256 _index) external view returns (
        address owner,
        address addr,
        address info,
        uint256 pmType
    );

    function deployNewPositionManagers(
        address _owner,
        uint256[] memory _types,
        uint256[] memory _blockIndexes,
        address[] memory _collaterals,
        address[] memory _borroweds,
        bytes[] memory _params
    ) external;

    function addNewPositionManagerType(string memory name, address implementation, address info) external;
    function upgradePositionManagerType(uint256 _type, address _implementation, address _info) external;
    function disablePositionManagerType(uint256 _type) external;
    function getOwnedPositionManagerBy(address owner) external view returns (address[] memory);
}
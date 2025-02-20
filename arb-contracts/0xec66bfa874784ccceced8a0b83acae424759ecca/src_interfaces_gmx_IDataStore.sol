// SPDX-License-Identifier: BUSL-1.1

pragma solidity ^0.8.0;

interface IDataStore {
    function getBool(bytes32 key) external view returns (bool);
    function getUint(bytes32 key) external view returns (uint256);

    function getAddressCount(bytes32 setKey) external view returns (uint256);

    function getAddressValuesAt(bytes32 setKey, uint256 start, uint256 end) external view returns (address[] memory);

    function containsAddress(bytes32 setKey, address value) external view returns (bool);
}
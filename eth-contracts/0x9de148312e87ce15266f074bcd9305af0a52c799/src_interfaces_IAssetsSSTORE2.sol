// SPDX-License-Identifier: MIT
pragma solidity ^0.8.21;

interface IAssetsSSTORE2 {
    function addAsset(string memory key, bytes memory asset) external;
    function loadAsset(string memory key) external view returns (bytes memory);
    function loadAsset(string memory key, bool decompress) external view returns (bytes memory);
}
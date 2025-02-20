// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

interface ICentralAuthorizationRegistry {
    function addAuthorizedContract(address contractAddress) external;
    function removeAuthorizedContract(address contractAddress) external;
    function isAuthorized(address contractAddress) external view returns (bool);
    function getAuthorizedContracts() external view returns (address[] memory);
    function registerPirateNftContract(address collectionAddress) external;
    function getPirateNftContract(address collectionAddress) external view returns (address);
    function setContractAddress(bytes32 interfaceId, address contractAddress) external;
    function getContractAddress(bytes32 interfaceId) external view returns (address);
    function isAdmin(address _user) external view returns (bool);
}
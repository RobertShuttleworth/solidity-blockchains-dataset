// SPDX-License-Identifier: MIT

pragma solidity 0.8.27;

interface IMultiPlatformSaleFactory {
  event ProjectCreated(address indexed project, uint256 index);

  function owner() external view returns (address);

  function beacon() external view returns (address);

  function savior() external view returns (address);

  function saleGateway() external view returns (address);

  function operational() external view returns (address);

  function marketing() external view returns (address);

  function treasury() external view returns (address);

  function operationalPercentage_d2() external view returns (uint256);

  function marketingPercentage_d2() external view returns (uint256);

  function treasuryPercentage_d2() external view returns (uint256);

  function allProjectsLength() external view returns (uint256);

  function allUsdPaymentTokensLength() external view returns (uint256);

  function allPlatformsLength() external view returns (uint256);

  function allChainsStakedLength() external view returns (uint256);

  function allPlatforms(uint256) external view returns (string calldata);

  function allProjects(uint256) external view returns (address);

  function allUsdPaymentTokens(uint256) external view returns (address);

  function allChainsStaked(uint256) external view returns (uint256);

  function getPlatformIndex(string calldata) external view returns (uint256);

  function getUsdPaymentTokenIndex(address) external view returns (uint256);

  function getChainStakedIndex(uint256) external view returns (uint256);

  function isKnown(address) external view returns (bool);

  function isPlatformSupported(string calldata) external view returns (bool);

  function createProject(
    uint128,
    uint128,
    uint256,
    uint256[] calldata,
    uint256,
    uint256[4] calldata,
    address,
    string[3] calldata
  ) external returns (address);

  function addUsdPaymentToken(address) external;

  function removeUsdPaymentToken(address) external;

  function addChainStaked(uint256[] calldata) external;

  function removeChainStaked(uint256[] calldata) external;

  function addPlatform(string calldata) external;

  function removePlatform(string calldata _platform) external;

  function setVault(address, address, address) external;

  function setVaultPercentage_d2(uint256, uint256, uint256) external;

  function config(address, address, address) external;
}
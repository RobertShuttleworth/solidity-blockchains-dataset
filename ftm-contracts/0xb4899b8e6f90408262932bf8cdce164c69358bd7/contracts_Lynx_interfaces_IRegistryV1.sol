// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.24;

import "./contracts_AdministrationContracts_IContractRegistryBase.sol";
import "./contracts_Lynx_interfaces_IGlobalLock.sol";

interface IRegistryV1Functionality is IContractRegistryBase, IGlobalLock {
  // **** Locking mechanism ****

  function isTradersPortalAndLocker(
    address _address
  ) external view returns (bool);

  function isTriggersAndLocker(address _address) external view returns (bool);

  function isTradersPortalOrTriggersAndLocker(
    address _address
  ) external view returns (bool);
}

interface IRegistryV1 is IRegistryV1Functionality {
  // **** Public Storage params ****

  function feesManagers(address asset) external view returns (address);

  function orderBook() external view returns (address);

  function tradersPortal() external view returns (address);

  function triggers() external view returns (address);

  function tradeIntentsVerifier() external view returns (address);

  function liquidityIntentsVerifier() external view returns (address);

  function chipsIntentsVerifier() external view returns (address);

  /**
   * @return An array of all supported trading floors
   */
  function getAllSupportedTradingFloors()
    external
    view
    returns (address[] memory);

  /**
   * @return An array of all supported settlement assets
   */
  function getSettlementAssetsForTradingFloor(
    address _tradingFloor
  ) external view returns (address[] memory);

  /**
   * @return The spender role address that is set for this chip
   */
  function getValidSpenderTargetForChipByRole(
    address chip,
    string calldata role
  ) external view returns (address);

  /**
   * @return the address of the valid 'burnHandler' for the chip
   */
  function validBurnHandlerForChip(
    address chip
  ) external view returns (address);

  /**
   * @return The address matching for the given role
   */
  function getDynamicRoleAddress(
    string calldata _role
  ) external view returns (address);
}
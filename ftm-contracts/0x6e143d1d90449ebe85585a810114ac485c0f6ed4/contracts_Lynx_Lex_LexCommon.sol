// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.24;

import "./contracts_AdministrationContracts_AcceptableImplementationClaimableAdminStorage.sol";
import "./contracts_Lynx_interfaces_ITradingFloorV1.sol";
import "./contracts_Lynx_Common_CommonScales.sol";

/**
 * @title LexCommon
 * @dev For Lex contracts to inherit from, holding common variables and modifiers
 */
contract LexCommon is
  CommonScales,
  AcceptableRegistryImplementationClaimableAdminStorage
{
  IERC20 public underlying;

  ITradingFloorV1 public tradingFloor;

  function initializeLexCommon(
    ITradingFloorV1 _tradingFloor,
    IERC20 _underlying
  ) public {
    require(
      address(tradingFloor) == address(0) && address(underlying) == address(0),
      "Initialized"
    );
    tradingFloor = _tradingFloor;
    underlying = _underlying;
  }

  modifier onlyTradingFloor() {
    require(msg.sender == address(tradingFloor), "TRADING_FLOOR_ONLY");
    _;
  }
}
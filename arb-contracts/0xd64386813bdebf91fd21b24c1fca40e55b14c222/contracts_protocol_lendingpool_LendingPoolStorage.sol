// SPDX-License-Identifier: agpl-3.0
pragma solidity 0.6.12;

import {UserConfiguration} from './contracts_protocol_libraries_configuration_UserConfiguration.sol';
import {ReserveConfiguration} from './contracts_protocol_libraries_configuration_ReserveConfiguration.sol';
import {ReserveLogic} from './contracts_protocol_libraries_logic_ReserveLogic.sol';
import {ILendingPoolAddressesProvider} from './contracts_interfaces_ILendingPoolAddressesProvider.sol';
import {DataTypes} from './contracts_protocol_libraries_types_DataTypes.sol';

contract LendingPoolStorage {
  using ReserveLogic for DataTypes.ReserveData;
  using ReserveConfiguration for DataTypes.ReserveConfigurationMap;
  using UserConfiguration for DataTypes.UserConfigurationMap;

  ILendingPoolAddressesProvider internal _addressesProvider;

  mapping(address => DataTypes.ReserveData) internal _reserves;
  mapping(address => DataTypes.UserConfigurationMap) internal _usersConfig;

  // the list of the available reserves, structured as a mapping for gas savings reasons
  mapping(uint256 => address) internal _reservesList;

  uint256 internal _reservesCount;

  bool internal _paused;

  uint256 internal _maxStableRateBorrowSizePercent;

  uint256 internal _flashLoanPremiumTotal;

  uint256 internal _maxNumberOfReserves;

  // Deposit limits for reserves.
  mapping(address => uint256) public depositLimit;
}
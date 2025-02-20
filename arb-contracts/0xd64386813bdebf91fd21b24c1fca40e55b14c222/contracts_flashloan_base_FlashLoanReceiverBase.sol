// SPDX-License-Identifier: agpl-3.0
pragma solidity 0.6.12;

import {SafeMath} from './contracts_dependencies_openzeppelin_contracts_SafeMath.sol';
import {IERC20} from './contracts_dependencies_openzeppelin_contracts_IERC20.sol';
import {SafeERC20} from './contracts_dependencies_openzeppelin_contracts_SafeERC20.sol';
import {IFlashLoanReceiver} from './contracts_flashloan_interfaces_IFlashLoanReceiver.sol';
import {ILendingPoolAddressesProvider} from './contracts_interfaces_ILendingPoolAddressesProvider.sol';
import {ILendingPool} from './contracts_interfaces_ILendingPool.sol';

abstract contract FlashLoanReceiverBase is IFlashLoanReceiver {
  using SafeERC20 for IERC20;
  using SafeMath for uint256;

  ILendingPoolAddressesProvider public immutable override ADDRESSES_PROVIDER;
  ILendingPool public immutable override LENDING_POOL;

  constructor(ILendingPoolAddressesProvider provider) public {
    ADDRESSES_PROVIDER = provider;
    LENDING_POOL = ILendingPool(provider.getLendingPool());
  }
}
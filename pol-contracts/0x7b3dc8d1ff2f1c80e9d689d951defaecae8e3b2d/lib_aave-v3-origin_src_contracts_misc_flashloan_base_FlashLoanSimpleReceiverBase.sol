// SPDX-License-Identifier: MIT
pragma solidity ^0.8.10;

import {IFlashLoanSimpleReceiver} from './lib_aave-v3-origin_src_contracts_misc_flashloan_interfaces_IFlashLoanSimpleReceiver.sol';
import {IPoolAddressesProvider} from './lib_aave-v3-origin_src_contracts_interfaces_IPoolAddressesProvider.sol';
import {IPool} from './lib_aave-v3-origin_src_contracts_interfaces_IPool.sol';

/**
 * @title FlashLoanSimpleReceiverBase
 * @author Aave
 * @notice Base contract to develop a flashloan-receiver contract.
 */
abstract contract FlashLoanSimpleReceiverBase is IFlashLoanSimpleReceiver {
  IPoolAddressesProvider public immutable override ADDRESSES_PROVIDER;
  IPool public immutable override POOL;

  constructor(IPoolAddressesProvider provider) {
    ADDRESSES_PROVIDER = provider;
    POOL = IPool(provider.getPool());
  }
}
// SPDX-License-Identifier: agpl-3.0
pragma solidity 0.6.12;

import {ILendingPool} from './contracts_interfaces_ILendingPool.sol';
import {IDelegationToken} from './contracts_interfaces_IDelegationToken.sol';
import {Errors} from './contracts_protocol_libraries_helpers_Errors.sol';
import {AToken} from './contracts_protocol_tokenization_AToken.sol';

/**
 * @title Aave AToken enabled to delegate voting power of the underlying asset to a different address
 * @dev The underlying asset needs to be compatible with the COMP delegation interface
 * @author Aave
 */
contract DelegationAwareAToken is AToken {
  modifier onlyPoolAdmin {
    require(
      _msgSender() == ILendingPool(_pool).getAddressesProvider().getPoolAdmin(),
      Errors.CALLER_NOT_POOL_ADMIN
    );
    _;
  }

  /**
   * @dev Delegates voting power of the underlying asset to a `delegatee` address
   * @param delegatee The address that will receive the delegation
   **/
  function delegateUnderlyingTo(address delegatee) external onlyPoolAdmin {
    IDelegationToken(_underlyingAsset).delegate(delegatee);
  }
}
// SPDX-License-Identifier: agpl-3.0
pragma solidity 0.6.12;

import {AToken} from './contracts_protocol_tokenization_AToken.sol';
import {ILendingPool} from './contracts_interfaces_ILendingPool.sol';
import {IAaveIncentivesController} from './contracts_interfaces_IAaveIncentivesController.sol';

contract MockAToken is AToken {
  function getRevision() internal pure override returns (uint256) {
    return 0x2;
  }
}
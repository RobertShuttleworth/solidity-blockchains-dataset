// SPDX-License-Identifier: agpl-3.0
pragma solidity 0.6.12;

import {VariableDebtToken} from './contracts_protocol_tokenization_VariableDebtToken.sol';

contract MockVariableDebtToken is VariableDebtToken {
  function getRevision() internal pure override returns (uint256) {
    return 0x2;
  }
}
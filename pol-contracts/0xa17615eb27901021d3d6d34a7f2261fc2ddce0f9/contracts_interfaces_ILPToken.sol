// SPDX-License-Identifier: BSD 3-Clause

pragma solidity 0.8.9;

import "./contracts_libs_zeppelin_token_BEP20_IBEP20.sol";

interface ILPToken is IBEP20 {
  function getReserves() external view returns (uint, uint);
  function totalSupply() external view returns (uint);
}
// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.24;

import "./contracts_Lynx_Lex_PoolAccountant_PoolAccountantStorage.sol";
import "./contracts_Lynx_interfaces_PoolAccountantV1AdminEnums.sol";

/**
 * @title PoolAccountantBase
 * @notice Base contract with common functionality for the accountant to fill
 */
abstract contract PoolAccountantBase is
  PoolAccountantStorage,
  PoolAccountantV1AdminEnums
{
  modifier onlyLexPool() {
    require(msg.sender == address(lexPool), "!Auth");
    _;
  }

  event AddressUpdated(PoolAccountantAddressesEnum indexed enumCode, address a);
  event NumberUpdated(PoolAccountantV1NumbersEnum indexed enumCode, uint value);

  function accrueFunding(
    uint16 pairId
  ) public virtual returns (int256 valueLong, int256 valueShort, uint256 protocolFundingShare);

  function virtualBalance() internal view virtual returns (uint256);

  function pairTotalOpenInterest(
    uint256 pairIndex
  ) public view virtual returns (int256);
}
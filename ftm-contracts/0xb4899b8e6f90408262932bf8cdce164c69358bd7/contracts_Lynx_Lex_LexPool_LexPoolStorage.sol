// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.24;

import "./openzeppelin_contracts_token_ERC20_ERC20.sol";
import "./contracts_Lynx_Lex_LexCommon.sol";
import "./contracts_Lynx_Lex_LexPool_LexERC20.sol";

/**
 * @title LexPoolStorage
 * @dev Storage contract for LexPool
 */
abstract contract LexPoolStorage is LexCommon, LexERC20, LexPoolStructs {
  uint256 public underlyingDecimals;

  // ***** Roles *****

  IPoolAccountantFunctionality public poolAccountant;
  address public pnlRole;

  // ***** Depositing and Withdrawing *****

  // epoch => user => PendingDeposit
  mapping(uint256 => mapping(address => PendingDeposit)) public pendingDeposits;
  // epoch => user => PendingRedeem
  mapping(uint256 => mapping(address => PendingRedeem)) public pendingRedeems;

  // epoch => users who deposits on this epoch
  mapping(uint256 => address[]) public pendingDepositorsArr;
  // epoch => users who redeems on this epoch
  mapping(uint256 => address[]) public pendingRedeemersArr;

  uint256 public pendingDepositAmount;
  uint256 public pendingWithdrawalAmount;
  // Extra fraction allowed to be withdrawn when redeem processes
  uint256 public maxExtraWithdrawalAmountF;
  uint256 public minDepositAmount;

  // ***** Epochs *****

  uint256 public currentEpoch;
  uint256 public nextEpochStartMin; // Minimum timestamp that calling nextEpoch will be possible
  uint256 public currentExchangeRate;
  uint256 public epochsDelayDeposit;
  uint256 public epochsDelayRedeem;
  uint256 public epochDuration;

  // ***** Flags *****

  bool public immediateDepositAllowed;

  function initializeLexPoolStorage(
    ITradingFloorV1 _tradingFloor,
    ERC20 _underlying,
    uint _epochDuration
  ) internal {
    initializeLexERC20(
      string.concat("Lynx LP ", _underlying.symbol()),
      string.concat("lx", _underlying.symbol())
    );

    initializeLexCommon(_tradingFloor, IERC20(_underlying));
    underlyingDecimals = _underlying.decimals();
    epochDuration = _epochDuration;
  }
}
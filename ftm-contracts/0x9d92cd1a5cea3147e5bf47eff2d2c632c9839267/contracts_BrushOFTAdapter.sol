// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {OFTAdapter} from "./layerzerolabs_oft-evm_contracts_OFTAdapter.sol";
import {Ownable} from "./openzeppelin_contracts_access_Ownable.sol";
import {IFantomBrush} from "./contracts_interfaces_IFantomBrush.sol";

/**
 * @title OFTAdapter Contract for BRUSH on Fantom
 * @dev OFTAdapter is a contract that adapts an ERC-20 token to the OFT functionality of BRUSH.
 * The contract operates in two phases:
 * - Phase 1 (first 100 days): Two-way bridging between Fantom and Sonic
 * - Phase 2 (after 100 days): One-way bridging from Fantom to Sonic only, with burning mechanism
 * @notice All BRUSH tokens bridged to Sonic are burned, not stored in the contract during Phase 2
 */
contract BrushOFTAdapter is OFTAdapter {
  /**
   * @dev Emitted when tokens are bridged from Sonic to Fantom
   * @param to Address receiving the bridged tokens
   * @param amount Amount of tokens bridged
   */
  event BridgeIn(address to, uint256 amount);

  /**
   * @dev Emitted when tokens are bridged from Fantom to Sonic
   * @param from Address sending the tokens
   * @param amount Amount of tokens bridged
   */
  event BridgeOut(address from, uint256 amount);

  /**
   * @dev Emitted when remaining tokens in the vault are burned at Phase 2
   * @param amount Amount of tokens burned
   */
  event BurnedBridgeBalance(uint256 amount);

  /// @dev Thrown when trying to bridge tokens back to Fantom during Phase 2
  error InvalidState();
  /// @dev Thrown when trying to burn vault balance before Phase 2 starts
  error BurnPhaseNotStarted();
  /// @dev Thrown when the BRUSH held in the adapter is already burned
  error BurnCompleted();
  /// @dev Thrown when the BRUSH token transfer fails
  error TokenTransferFailed();

  /// @dev Duration of Phase 1 (two-way bridging period) in seconds
  uint256 public constant TWO_WAY_BRIDGING = 100 days;

  /// @dev Timestamp when Phase 2 begins (burn phase)
  uint256 private immutable _burnStartTimestamp = block.timestamp + TWO_WAY_BRIDGING;

  /// @dev Timestamp when the BRUSH held in this contract was burned
  uint256 private _brushBurnedAtTimestamp;

  /**
   * @dev Constructor initializes the adapter with the Fantom BRUSH token and LayerZero endpoint
   * @param brush Address of the Fantom BRUSH token
   * @param lzEndpoint Address of the LayerZero endpoint
   */
  constructor(address brush, address lzEndpoint) OFTAdapter(brush, lzEndpoint, _msgSender()) Ownable(_msgSender()) {}

  function _debit(
    address from,
    uint256 amount,
    uint256 /* minAmount */,
    uint32 /* dstEid */
  ) internal override returns (uint256, uint256) {
    emit BridgeOut(from, amount);

    // Phase 1: Transfer tokens
    /// slither-disable-next-line arbitrary-from-in-transferfrom
    require(innerToken.transferFrom(from, address(this), amount), TokenTransferFailed());
    if (block.timestamp >= _burnStartTimestamp) {
      // Phase 2: Burn tokens
      IFantomBrush(address(innerToken)).burn(amount);
    }

    return (amount, amount);
  }

  function _credit(address to, uint256 amount, uint32 /* srcEid */) internal override returns (uint256) {
    // Phase 2: Reject unlocks
    require(block.timestamp < _burnStartTimestamp, InvalidState());

    emit BridgeIn(to, amount);

    // Phase 1: Unlock tokens
    require(innerToken.transfer(to, amount), TokenTransferFailed());

    return amount;
  }

  /**
   * @dev Burns all tokens held in the vault
   * @notice Can only be called after Phase 2 starts
   * @notice This function should be called at the beginning of Phase 2 to burn any remaining tokens
   */
  function burnRemainingTokens() external {
    require(block.timestamp >= _burnStartTimestamp, BurnPhaseNotStarted());
    require(_brushBurnedAtTimestamp == 0, BurnCompleted());

    _brushBurnedAtTimestamp = block.timestamp;

    uint256 balance = innerToken.balanceOf(address(this));

    emit BurnedBridgeBalance(balance);

    IFantomBrush(address(innerToken)).burn(balance);
  }

  /**
   * @dev Returns the timestamp when Phase 2 (burn phase) begins
   * @return Timestamp in seconds since unix epoch
   */
  function burnStartTimestamp() external view returns (uint256) {
    return _burnStartTimestamp;
  }
}
// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import {IBurnMintERC20} from "./src_v0.8_shared_token_ERC20_IBurnMintERC20.sol";

import {UpgradeableTokenPool} from "./src_v0.8_ccip_pools_GHO_UpgradeableTokenPool.sol";

abstract contract UpgradeableBurnMintTokenPoolAbstract is UpgradeableTokenPool {
  /// @notice Contains the specific burn call for a pool.
  /// @dev overriding this method allows us to create pools with different burn signatures
  /// without duplicating the underlying logic.
  function _burn(uint256 amount) internal virtual;

  /// @notice Burn the token in the pool
  /// @param amount Amount to burn
  /// @dev The whenHealthy check is important to ensure that even if a ramp is compromised
  /// we're able to stop token movement via ARM.
  function lockOrBurn(
    address originalSender,
    bytes calldata,
    uint256 amount,
    uint64 remoteChainSelector,
    bytes calldata
  )
    external
    virtual
    override
    onlyOnRamp(remoteChainSelector)
    checkAllowList(originalSender)
    whenHealthy
    returns (bytes memory)
  {
    _consumeOutboundRateLimit(remoteChainSelector, amount);
    _burn(amount);
    emit Burned(msg.sender, amount);
    return "";
  }

  /// @notice Mint tokens from the pool to the recipient
  /// @param receiver Recipient address
  /// @param amount Amount to mint
  /// @dev The whenHealthy check is important to ensure that even if a ramp is compromised
  /// we're able to stop token movement via ARM.
  function releaseOrMint(
    bytes memory,
    address receiver,
    uint256 amount,
    uint64 remoteChainSelector,
    bytes memory
  ) external virtual override whenHealthy onlyOffRamp(remoteChainSelector) {
    _consumeInboundRateLimit(remoteChainSelector, amount);
    IBurnMintERC20(address(i_token)).mint(receiver, amount);
    emit Minted(msg.sender, receiver, amount);
  }
}
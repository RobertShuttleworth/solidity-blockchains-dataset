// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import './openzeppelin_contracts_access_Ownable.sol';
import './openzeppelin_contracts_token_ERC20_extensions_IERC20Metadata.sol';
import './openzeppelin_contracts_token_ERC20_utils_SafeERC20.sol';
import './openzeppelin_contracts_token_ERC20_extensions_ERC20Burnable.sol';

contract Lock is Ownable {
  using SafeERC20 for IERC20;

  IERC20 public tokenAddress;
  uint256 public endLockTime;

  event TokensClaimed(address indexed user, uint256 amount);

  constructor() Ownable(msg.sender) {
    endLockTime = block.timestamp + 180 days;
  }

  /**
   * @dev To update the token address
   * @param tokenAddress_ Token address
   */
  function setTokenAddress(address tokenAddress_) external onlyOwner {
    tokenAddress = IERC20(tokenAddress_);
  }

  /**
   * @dev To claim tokens after claiming starts
   */
  function claimTokens() external onlyOwner {
    require(block.timestamp >= endLockTime, 'Lock has not ended yet');

    uint256 amount_ = tokenAddress.balanceOf(address(this));
    tokenAddress.safeTransfer(owner(), amount_);

    emit TokensClaimed(owner(), amount_);
  }

  /**
   * @dev To burn tokens
   * @param amount_ Amount of tokens to be burned
   */
  function burnTokens(uint256 amount_) external onlyOwner {
    ERC20Burnable(address(tokenAddress)).burn(amount_);
  }
}
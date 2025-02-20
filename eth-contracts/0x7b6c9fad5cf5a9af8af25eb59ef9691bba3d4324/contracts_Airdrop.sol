// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import './openzeppelin_contracts_access_Ownable.sol';
import './openzeppelin_contracts_token_ERC20_extensions_IERC20Metadata.sol';
import './openzeppelin_contracts_token_ERC20_utils_SafeERC20.sol';
import './openzeppelin_contracts_utils_ReentrancyGuard.sol';

contract Airdrop is Ownable, ReentrancyGuard {
  using SafeERC20 for IERC20;

  IERC20 public tokenAddress;
  bool public claimStarted;

  mapping(address => uint256) public userAidropAvailable;
  mapping(address => bool) public hasClaimed;

  event TokensClaimed(address indexed user, uint256 amount);

  constructor() Ownable(msg.sender) {}

  /**
   * @dev To add a user to the whitelist
   * @param user_ User address
   * @param amount_ Amount of tokens to be added to the whitelist
   */
  function addUserToWhitelist(address user_, uint256 amount_) external onlyOwner {
    userAidropAvailable[user_] = amount_;
  }

  /**
   * @dev To claim tokens after claiming starts
   */
  function claim() external nonReentrant {
    require(claimStarted, 'Claim has not started yet');
    require(hasClaimed[msg.sender] == false, 'Already claimed');
    require(userAidropAvailable[msg.sender] > 0, 'Nothing to claim');

    hasClaimed[msg.sender] = true;

    uint256 amount_ = userAidropAvailable[msg.sender];
    delete userAidropAvailable[msg.sender];

    tokenAddress.safeTransfer(msg.sender, amount_);

    emit TokensClaimed(msg.sender, amount_);
  }

  /**
   * @dev To update the token address
   * @param tokenAddress_ Token address
   */
  function setTokenAddress(address tokenAddress_) external onlyOwner {
    tokenAddress = IERC20(tokenAddress_);
  }

  /**
   * @dev To update the sale times
   * @param claimStarted_ New claimStarted value
   */
  function setClaimStarted(bool claimStarted_) external onlyOwner {
    claimStarted = claimStarted_;
  }
}
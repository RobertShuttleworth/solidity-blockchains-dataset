// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.28;

contract Constants {
  bytes32 public constant PRESALE_SELLER_ROLE = keccak256("PRESALE_SELLER_ROLE");
  bytes32 public constant PRESALE_MANAGER_ROLE = keccak256("PRESALE_MANAGER_ROLE");
  bytes32 public constant PRESALE_CRAWLER_ROLE = keccak256("PRESALE_CRAWLER_ROLE");

  bytes32 internal constant CLAIM_PARTICIPANT_TYPEHASH = keccak256("ClaimParticipant(address[] tokens_,string participant_,address claimer_,uint256 deadline_)");
  address internal constant ETH_ADDRESS = 0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE;
  address internal constant TOKEN = 0x1111111111111111111111111111111111111111;
  uint256 internal constant MIN = 10**18;
  uint256 internal constant PRECISION = 18;
}
// SPDX-License-Identifier: MIT
// Copyright (C) 2023-2024 Soccerverse Ltd

pragma solidity ^0.8.19;

import "./lib_openzeppelin-contracts_contracts_access_AccessControlEnumerable.sol";
import "./lib_openzeppelin-contracts_contracts_utils_Strings.sol";

import "./lib_democrit-evm_contracts_JsonUtils.sol";
import "./lib_delegation-contract_contracts_XayaDelegation.sol";

import "./src_Config.sol";

/**
 * @dev This contract is responsible for minting club shares (as packs are
 * bought) using Soccerverse admin commands.  It has delegation access to
 * g/sv accordingly, so it can send those moves.  It also keeps track of
 * how many shares have been minted for each club so far, to ensure we do
 * not attempt to mint over the supply cap.
 *
 * The actual selling of packs is handled by another contract, which uses
 * this one to perform the mints themselves.  By this separation, we can
 * in theory replace the sales contract if required, while keeping the
 * state about which shares have been minted already intact in this one.
 *
 * Note that this contract does not know which IDs are actually valid clubs.
 * It just keeps track of the number of shares minted for each ID, as
 * instructed by the sales contract.
 */
contract ClubMinter is AccessControlEnumerable
{

  string public constant gameId = Config.GAME_ID;

  /**
   * @dev Addresses with this role can mint shares and club SMC.  This is
   * granted to the sales contracts.
   */
  bytes32 public constant MINTER_ROLE = keccak256 ("MINTER_ROLE");

  /** @dev Delegation contract used to send moves.  */
  XayaDelegation public immutable delegator;

  /** @dev Maximum allowed supply for each share.  */
  uint public constant shareSupply = 1_000_000;

  /** @dev Number of shares minted for each club ID.  */
  mapping (uint => uint) public sharesMinted;

  /** @dev Emitted when new shares are minted.  */
  event SharesMinted (uint indexed clubId, uint num, string receiver,
                      uint totalMinted, uint remaining);
  /** @dev Emitted when SMC are minted to a club's balance.  */
  event ClubSmcMinted (uint indexed clubId, uint num);

  constructor (XayaDelegation d)
  {
    _grantRole (DEFAULT_ADMIN_ROLE, msg.sender);
    delegator = d;

    /* In case we need to pay fees for the minting moves, approve WCHI.  */
    d.accounts ().wchiToken ().approve (address (d), type (uint256).max);
  }

  /**
   * @dev Returns the remaining amount of shares that can be minted
   * for a given club.
   */
  function sharesAvailable (uint clubId) public view returns (uint)
  {
    return shareSupply - sharesMinted[clubId];
  }

  /**
   * @dev Requests to mint some shares of a given club.
   */
  function mintShares (uint clubId, uint num, string calldata receiver)
      public onlyRole (MINTER_ROLE)
  {
    uint minted = sharesMinted[clubId];
    minted += num;
    require (minted <= shareSupply, "mint cap exceeded");

    string memory escapedReceiver = JsonUtils.escapeString (receiver);
    string memory mintCmd = string (abi.encodePacked (
      "{",
        "\"s\":{\"club\":", Strings.toString (clubId), "},",
        "\"r\":", escapedReceiver, ",",
        "\"n\":", Strings.toString (num),
      "}"
    ));
    string[] memory path = new string[] (3);
    path[0] = "cmd";
    path[1] = "mint";
    path[2] = "shares";
    delegator.sendHierarchicalMove ("g", gameId, path, mintCmd);

    sharesMinted[clubId] = minted;
    emit SharesMinted (clubId, num, receiver, minted, shareSupply - minted);
  }

  /**
   * @dev Requests to mint SMC to a club's balance.
   */
  function mintClubSmc (uint clubId, uint num)
      public onlyRole (MINTER_ROLE)
  {
    string memory mintCmd = string (abi.encodePacked (
      "{",
        "\"c\":", Strings.toString (clubId), ",",
        "\"n\":", Strings.toString (num),
      "}"
    ));
    string[] memory path = new string[] (3);
    path[0] = "cmd";
    path[1] = "mint";
    path[2] = "clubsmc";
    delegator.sendHierarchicalMove ("g", gameId, path, mintCmd);

    emit ClubSmcMinted (clubId, num);
  }

  /**
   * @dev Data for the minting of club shares and SMC in batch.
   */
  struct MintForClub
  {

    /** @dev The club this relates to.  */
    uint clubId;

    /** @dev Number of shares to mint (or zero to mint no shares).  */
    uint numShares;

    /** @dev Receiver account name for shares.  */
    string receiver;

    /** @dev Number of SMC to mint to the club (or zero to mint none).  */
    uint smc;

  }

  /**
   * @dev Batch mints shares and/or club SMC.
   */
  function batchMint (MintForClub[] calldata clubs)
      public onlyRole (MINTER_ROLE)
  {
    for (uint i = 0; i < clubs.length; ++i)
      {
        if (clubs[i].numShares > 0)
          mintShares (clubs[i].clubId, clubs[i].numShares, clubs[i].receiver);
        if (clubs[i].smc > 0)
          mintClubSmc (clubs[i].clubId, clubs[i].smc);
      }
  }

}
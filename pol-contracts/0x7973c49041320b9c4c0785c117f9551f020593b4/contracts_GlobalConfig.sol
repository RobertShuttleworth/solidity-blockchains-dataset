/*
    SPDX-License-Identifier: Apache-2.0
    Copyright 2023 Reddit, Inc
    Licensed under the Apache License, Version 2.0 (the "License");
    you may not use this file except in compliance with the License.
    You may obtain a copy of the License at
    http://www.apache.org/licenses/LICENSE-2.0
    Unless required by applicable law or agreed to in writing, software
    distributed under the License is distributed on an "AS IS" BASIS,
    WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
    See the License for the specific language governing permissions and
    limitations under the License.
*/
pragma solidity ^0.8.9;

import "./openzeppelin_contracts_access_Ownable.sol";
import "./openzeppelin_contracts_utils_structs_EnumerableSet.sol";

error GlobalConfig__ZeroAddress();
error GlobalConfig__TokenIsNotAuthorized();
error GlobalConfig__TokenAlreadyAuthorized();
error GlobalConfig__AddressIsNotFiltered(address operator);
error GlobalConfig__AddressAlreadyFiltered(address operator);
error GlobalConfig__CodeHashIsNotFiltered(bytes32 codeHash);
error GlobalConfig__CodeHashAlreadyFiltered(bytes32 codeHash);
error GlobalConfig__CannotFilterEOAs();
/// @dev Following original Operator Filtering error signature to ensure compatibility
error AddressFiltered(address filtered);
/// @dev Following original Operator Filtering error signature to ensure compatibility
error CodeHashFiltered(address account, bytes32 codeHash);

/**
 * @title GlobalConfig
 * @notice One contract that maintains config values that other contracts read from - so if you need to change, only need to change here.
 * @dev Used by the [Splitter.sol] and [RedditCollectibleAvatars.sol].
 */
contract GlobalConfig is Ownable {
  using EnumerableSet for EnumerableSet.AddressSet;
  using EnumerableSet for EnumerableSet.Bytes32Set;

  event RedditRoyaltyAddressUpdated(address indexed oldAddress, address indexed newAddress);
  event AuthorizedERC20sUpdated(bool indexed removed, address indexed token, uint length);
  event FilteredOperatorUpdated(bool indexed filtered, address indexed operator, uint length);
  event FilteredCodeHashUpdated(bool indexed filtered, bytes32 indexed codeHash, uint length);
  event MinterUpdated(address current, address prevMinter, address removedMinter);
  event PreviousMinterCleared(address removedMinter);

  /// @dev Initialized accounts have a nonzero codehash (see https://eips.ethereum.org/EIPS/eip-1052)
  bytes32 constant private EOA_CODEHASH = keccak256("");

  // ------------------------------------------------------------------------------------
  // VARIABLES BLOCK, MAKE SURE ONLY ADD TO THE END

  /// @dev Referenced by the royalty splitter contract to withdraw reddit's share of NFT royalties
  address public redditRoyalty;

  /// @dev Set of ERC20 tokens authorized for royalty withdrawal by Reddit in the splitter contract
  EnumerableSet.AddressSet private authorizedERC20s;

  /// @dev Set of filtered (restricted/blocked) operator addresses
  EnumerableSet.AddressSet private filteredOperators;
  /// @dev Set of filtered (restricted/blocked) code hashes
  EnumerableSet.Bytes32Set private filteredCodeHashes;

  /// @dev Wallet address of the `minter` wallet
  address public minter;
  /// @dev Wallet address of the previous `minter` wallet to have no downtime during minter rotation
  address public prevMinter;

  // END OF VARS
  // ------------------------------------------------------------------------------------

  constructor(
    address _owner, 
    address _redditRoyalty, 
    address _minter,
    address[] memory _authorizedERC20s,
    address[] memory _filteredOperators,
    bytes32[] memory _filteredCodeHashes
  ) {
    _updateRedditRoyaltyAddress(_redditRoyalty);
    _updateMinter(_minter);

    for (uint i=0; i < _authorizedERC20s.length;) {
      authorizedERC20s.add(_authorizedERC20s[i]);
      unchecked { ++i; }
    }

    for (uint i=0; i < _filteredOperators.length;) {
      filteredOperators.add(_filteredOperators[i]);
      unchecked { ++i; }
    }

    for (uint i=0; i < _filteredCodeHashes.length;) {
      filteredCodeHashes.add(_filteredCodeHashes[i]);
      unchecked { ++i; }
    }

    if (_owner != _msgSender()) {
      Ownable.transferOwnership(_owner);
    }
  }

  /// @notice Update address of Reddit royalty receiver
  function updateRedditRoyaltyAddress(address newRedditAddress) external onlyOwner {
    _updateRedditRoyaltyAddress(newRedditAddress);
  }

  /// @notice Delete an authorized ERC20 token
  function deleteAuthorizedToken(address token) external onlyOwner {
    emit AuthorizedERC20sUpdated(true, token, authorizedERC20s.length() - 1);
    if (!authorizedERC20s.remove(token)) {
      revert GlobalConfig__TokenIsNotAuthorized();
    }
  }

  /// @notice Add an authorized ERC20 token
  function addAuthorizedToken(address token) external onlyOwner {
    emit AuthorizedERC20sUpdated(false, token, authorizedERC20s.length() + 1);
    if (!authorizedERC20s.add(token)) {
      revert GlobalConfig__TokenAlreadyAuthorized();
    }
  }

  /// @notice Array of authorized ERC20 tokens
  function authorizedERC20sArray() external view returns (address[] memory) {
    return authorizedERC20s.values();
  }

  /// @notice Checks if ERC20 token is authorized
  function authorizedERC20(address token) external view returns (bool) {
    return authorizedERC20s.contains(token);
  }

  /// @notice Add a filtered (restricted) operator address
  function addFilteredOperator(address operator) external onlyOwner {
    emit FilteredOperatorUpdated(true, operator, filteredOperators.length() + 1);
    if (!filteredOperators.add(operator)) {
      revert GlobalConfig__AddressAlreadyFiltered(operator);
    }
  }

  /// @notice Delete a filtered (restricted) operator address
  function deleteFilteredOperator(address operator) external onlyOwner {
    emit FilteredOperatorUpdated(false, operator, filteredOperators.length() - 1);
    if (!filteredOperators.remove(operator)) {
      revert GlobalConfig__AddressIsNotFiltered(operator);
    }
  }

  /// @notice Add a filtered (restricted) code hash
  /// @dev This will allow adding the bytes32(0) codehash, which could result in unexpected behavior,
  ///      since calling `isCodeHashFiltered` will return true for bytes32(0), which is the codeHash of any
  ///      un-initialized account. Since un-initialized accounts have no code, the registry will not validate
  ///      that an un-initalized account's codeHash is not filtered. By the time an account is able to
  ///      act as an operator (an account is initialized or a smart contract exclusively in the context of its
  ///      constructor), it will have a codeHash of EOA_CODEHASH, which cannot be filtered.
  function addFilteredCodeHash(bytes32 codeHash) external onlyOwner {
    if (codeHash == EOA_CODEHASH) {
      revert GlobalConfig__CannotFilterEOAs();
    }
    emit FilteredCodeHashUpdated(true, codeHash, filteredCodeHashes.length() + 1);
    if (!filteredCodeHashes.add(codeHash)) {
      revert GlobalConfig__CodeHashAlreadyFiltered(codeHash);
    }
  }

  /// @notice Delete a filtered (restricted) code hash
  function deleteFilteredCodeHash(bytes32 codeHash) external onlyOwner {
    if (codeHash == EOA_CODEHASH) {
      revert GlobalConfig__CannotFilterEOAs();
    }
    emit FilteredCodeHashUpdated(false, codeHash, filteredCodeHashes.length() - 1);
    if (!filteredCodeHashes.remove(codeHash)) {
      revert GlobalConfig__CodeHashIsNotFiltered(codeHash);
    }
  } 

  /// @notice Returns true if operator is not filtered, either by address or codeHash.
  /// @dev Will *revert* if an operator or its codehash is filtered with an error that is
  ///      more informational than a false boolean.
  function isOperatorAllowed(address operator) external view returns (bool) {
    if (filteredOperators.contains(operator)) {
      revert AddressFiltered(operator);
    }
    if (operator.code.length > 0) {
      bytes32 codeHash = operator.codehash;
      if (filteredCodeHashes.contains(codeHash)) {
        revert CodeHashFiltered(operator, codeHash);
      }
    }
    return true;
  }

  /**
   * @notice Updates the `minter` wallet address on the contract 
   * (note that only the `owner` wallet can execute this action)
   */
  function updateMinter(address account) public onlyOwner {
    _updateMinter(account);
  }

  function clearPreviousMinter() public onlyOwner {
    emit PreviousMinterCleared({removedMinter: prevMinter});
    prevMinter = address(0);
  }

  function _updateRedditRoyaltyAddress(address newRedditAddress) internal {
    if (newRedditAddress == address(0)) {
      revert GlobalConfig__ZeroAddress();
    }
    emit RedditRoyaltyAddressUpdated(redditRoyalty, newRedditAddress);
    redditRoyalty = newRedditAddress;
  }

  function _updateMinter(address newMinter) internal {
    if (newMinter == address(0)){
      revert GlobalConfig__ZeroAddress();
    }
    emit MinterUpdated({current: newMinter, prevMinter: minter, removedMinter: prevMinter});
    prevMinter = minter;
    minter = newMinter;
  }
}
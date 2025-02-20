//SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.23;

import {AccessControlEnumerable} from './openzeppelin_contracts_access_extensions_AccessControlEnumerable.sol';

// how we store it internally
struct MetadataHistoryItem {
  string reason;
  string json;
  uint256 date;
}

contract TheRealestCertificate is AccessControlEnumerable {
  MetadataHistoryItem[] private metadataHistory;
  string public version = '1.0.0';

  event UpdatedMetadata(MetadataHistoryItem indexed data);
  event ContractURIUpdated();

  constructor(string memory _initialMetadataJSON) {
    _grantRole(DEFAULT_ADMIN_ROLE, _msgSender());
    updateMetadata('Initial', _initialMetadataJSON);
  }

  // core update functions
  function updateMetadata(string memory reason, string memory json) public returns (bool) {
    require(isAdmin(_msgSender()), 'Must be admin.');
    require(bytes(json).length != 0, 'Must not be empty.');

    MetadataHistoryItem memory newItem = MetadataHistoryItem({
      reason: reason,
      json: json,
      date: block.timestamp
    });
    metadataHistory.push(newItem);
    emit UpdatedMetadata(newItem);
    emit ContractURIUpdated();
    return true;
  }

  // core view functions
  function metadata() public view returns (MetadataHistoryItem memory) {
    return metadataHistory[metadataHistory.length - 1];
  }
  function history() public view returns (MetadataHistoryItem[] memory) {
    return metadataHistory;
  }

  // ERC7572 support
  // Spec: https://github.com/ethereum/ERCs/pull/150/files#diff-d307389098602ec5613414f07f19d8b289a45629ef496827786aedb606d304f5R47
  function contractURI() external view returns (string memory) {
    return
      string.concat(
        'data:application/json;utf8,',
        this.metadata().json
      );
  }

  // role functions
  function getAdmins() public view virtual returns (address[] memory) {
    uint256 len = getRoleMemberCount(DEFAULT_ADMIN_ROLE);
    address[] memory addOut = new address[](len);
    for (uint256 i; i < len; i++) {
      addOut[i] = getRoleMember(DEFAULT_ADMIN_ROLE, i);
    }
    return addOut;
  }

  function isAdmin(address _address) public view virtual returns (bool) {
    return hasRole(DEFAULT_ADMIN_ROLE, _address);
  }

  function addAdmin(
    address _address
  ) public virtual onlyRole(DEFAULT_ADMIN_ROLE) {
    grantRole(DEFAULT_ADMIN_ROLE, _address);
  }

  function removeAdmin(
    address _address
  ) public virtual onlyRole(DEFAULT_ADMIN_ROLE) {
    revokeRole(DEFAULT_ADMIN_ROLE, _address);
  }

  function renounceAdmin() public virtual onlyRole(DEFAULT_ADMIN_ROLE) {
    renounceRole(DEFAULT_ADMIN_ROLE, _msgSender());
  }
}
//SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {ContextUpgradeable} from './openzeppelin_contracts-upgradeable_utils_ContextUpgradeable.sol';
import {Initializable} from './openzeppelin_contracts-upgradeable_proxy_utils_Initializable.sol';
import {Proxied} from './hardhat-deploy_solc_0.8_proxy_Proxied.sol';

contract ProxyAdminManagerUpgradeable is Initializable, ContextUpgradeable, Proxied {
  /// @custom:storage-location erc7201:kommunitas.storage.ProxyAdminManager
  struct ProxyAdminManagerStorage {
    address _pendingProxyAdmin;
  }

  // keccak256(abi.encode(uint256(keccak256("kommunitas.storage.ProxyAdminManager")) - 1)) & ~bytes32(uint256(0xff))
  bytes32 private constant ProxyAdminManagerStorageLocation =
    0x8a59f7a64c66470bf640c97c76846f17f243529240a7e0230806f27e52406200;

  function _getProxyAdminManagerStorage() private pure returns (ProxyAdminManagerStorage storage $) {
    assembly {
      $.slot := ProxyAdminManagerStorageLocation
    }
  }

  error PendingProxyAdminUnauthorizedAccount(address account);

  error ProxyAdminInvalidAccount(address account);

  event ProxyAdminTransferStarted(address indexed previousProxyAdmin, address indexed newProxyAdmin);

  event ProxyAdminTransferred(address indexed previousProxyAdmin, address indexed newProxyAdmin);

  function __ProxyAdminManager_init(address _initialProxyAdmin) internal onlyInitializing {
    __ProxyAdminManager_init_unchained(_initialProxyAdmin);
  }

  function __ProxyAdminManager_init_unchained(address _initialProxyAdmin) internal onlyInitializing {
    if (_initialProxyAdmin == address(0)) {
      revert ProxyAdminInvalidAccount(address(0));
    }
    assembly {
      sstore(0xb53127684a568b3173ae13b9f8a6016e243e63b6e8ee1178d6a717850b5d6103, _initialProxyAdmin)
    }
  }

  function proxyAdmin() external view virtual returns (address) {
    return _proxyAdmin();
  }

  function pendingProxyAdmin() public view virtual returns (address) {
    ProxyAdminManagerStorage storage $ = _getProxyAdminManagerStorage();
    return $._pendingProxyAdmin;
  }

  function transferProxyAdmin(address _newProxyAdmin) external virtual proxied {
    ProxyAdminManagerStorage storage $ = _getProxyAdminManagerStorage();
    $._pendingProxyAdmin = _newProxyAdmin;
    emit ProxyAdminTransferStarted(_proxyAdmin(), _newProxyAdmin);
  }

  function _transferProxyAdmin(address _newProxyAdmin) internal virtual {
    ProxyAdminManagerStorage storage $ = _getProxyAdminManagerStorage();
    delete $._pendingProxyAdmin;
    address oldProxyAdmin = _proxyAdmin();
    assembly {
      sstore(0xb53127684a568b3173ae13b9f8a6016e243e63b6e8ee1178d6a717850b5d6103, _newProxyAdmin)
    }
    emit ProxyAdminTransferred(oldProxyAdmin, _newProxyAdmin);
  }

  function acceptProxyAdmin() external virtual {
    address sender = _msgSender();
    if (pendingProxyAdmin() != sender) {
      revert PendingProxyAdminUnauthorizedAccount(sender);
    }
    _transferProxyAdmin(sender);
  }
}
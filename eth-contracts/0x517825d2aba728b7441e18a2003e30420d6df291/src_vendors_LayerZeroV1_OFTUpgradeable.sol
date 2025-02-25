// SPDX-License-Identifier: MIT

pragma solidity 0.8.18;

import { ERC20Upgradeable, IERC20Upgradeable } from "./lib_openzeppelin-contracts-upgradeable_contracts_token_ERC20_ERC20Upgradeable.sol";
import { IERC165Upgradeable } from "./lib_openzeppelin-contracts-upgradeable_contracts_interfaces_IERC165Upgradeable.sol";
import { IOFTUpgradeable } from "./src_vendors_LayerZeroV1_IOFTUpgradeable.sol";
import { OFTCoreUpgradeable } from "./src_vendors_LayerZeroV1_OFTCoreUpgradeable.sol";
import { Initializable } from "./lib_openzeppelin-contracts-upgradeable_contracts_proxy_utils_Initializable.sol";

// override decimal() function is needed
contract OFTUpgradeable is Initializable, OFTCoreUpgradeable, ERC20Upgradeable, IOFTUpgradeable {
  function __OFTUpgradeable_init(
    string memory _name,
    string memory _symbol,
    address _lzEndpoint
  ) internal onlyInitializing {
    __ERC20_init_unchained(_name, _symbol);
    __Ownable_init_unchained();
    __LzAppUpgradeable_init_unchained(_lzEndpoint);
  }

  function __OFTUpgradeable_init_unchained(
    string memory _name,
    string memory _symbol,
    address _lzEndpoint
  ) internal onlyInitializing {}

  function supportsInterface(
    bytes4 interfaceId
  ) public view virtual override(OFTCoreUpgradeable, IERC165Upgradeable) returns (bool) {
    return
      interfaceId == type(IOFTUpgradeable).interfaceId ||
      interfaceId == type(IERC20Upgradeable).interfaceId ||
      super.supportsInterface(interfaceId);
  }

  function token() public view virtual override returns (address) {
    return address(this);
  }

  function circulatingSupply() public view virtual override returns (uint) {
    return totalSupply();
  }

  function _debitFrom(
    address _from,
    uint16,
    bytes memory,
    uint _amount
  ) internal virtual override returns (uint) {
    address spender = _msgSender();
    if (_from != spender) _spendAllowance(_from, spender, _amount);
    _burn(_from, _amount);
    return _amount;
  }

  function _creditTo(
    uint16,
    address _toAddress,
    uint _amount
  ) internal virtual override returns (uint) {
    _mint(_toAddress, _amount);
    return _amount;
  }

  /**
   * @dev This empty reserved space is put in place to allow future versions to add new
   * variables without shifting down storage in the inheritance chain.
   * See https://docs.openzeppelin.com/contracts/4.x/upgradeable#storage_gaps
   */
  uint[50] private __gap;
}
// SPDX-License-Identifier: BUSL-1.1
// This code is made available under the terms and conditions of the Business Source License 1.1 (BUSL-1.1).
// The act of publishing this code is driven by the aim to promote transparency and facilitate its utilization for educational purposes.

pragma solidity 0.8.18;

import { ERC20Upgradeable } from "./lib_openzeppelin-contracts-upgradeable_contracts_token_ERC20_ERC20Upgradeable.sol";
import { OwnableUpgradeable } from "./lib_openzeppelin-contracts-upgradeable_contracts_access_OwnableUpgradeable.sol";

contract FlexPoint is ERC20Upgradeable, OwnableUpgradeable {
  mapping(address => bool) public isTransferrer;
  mapping(address => bool) public isMinter;

  event FlexPoint_SetMinter(address minter, bool prevAllow, bool newAllow);

  error FlexPoint_isNotTransferrer();
  error FlexPoint_NotMinter();

  modifier onlyMinter() {
    if (!isMinter[msg.sender]) revert FlexPoint_NotMinter();
    _;
  }

  function initialize() external initializer {
    OwnableUpgradeable.__Ownable_init();
    ERC20Upgradeable.__ERC20_init("Flex Point", "FP");
  }

  function setMinter(address minter, bool allow) external onlyOwner {
    emit FlexPoint_SetMinter(minter, isMinter[minter], allow);
    isMinter[minter] = allow;
  }

  function mint(address to, uint256 amount) public onlyMinter {
    _mint(to, amount);
  }

  function burn(address from, uint256 amount) public onlyMinter {
    _burn(from, amount);
  }

  function setTransferrer(address transferrer, bool isActive) external onlyOwner {
    isTransferrer[transferrer] = isActive;
  }

  function _transfer(address from, address to, uint256 amount) internal virtual override {
    if (!isTransferrer[msg.sender]) revert FlexPoint_isNotTransferrer();

    super._transfer(from, to, amount);
  }

  function transferFrom(
    address from,
    address to,
    uint256 amount
  ) public virtual override returns (bool) {
    _transfer(from, to, amount);
    return true;
  }
}
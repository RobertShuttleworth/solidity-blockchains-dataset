// SPDX-License-Identifier: MIT
pragma solidity 0.8.18;

import { ERC20 } from "./lib_openzeppelin-contracts_contracts_token_ERC20_ERC20.sol";
import { Ownable } from "./lib_openzeppelin-contracts_contracts_access_Ownable.sol";

contract TLFDX is ERC20, Ownable {
  mapping(address => bool) public isTransferer;
  mapping(address => bool) public isMinter;

  // Events
  event TLFDX_SetMinter(address minter, bool prevAllow, bool newAllow);
  event TLFDX_SetTransferer(address transferor, bool prevAllow, bool newAllow);

  // Errors
  error TLFDX_NotMinter();
  error TLFDX_IsNotTransferer();

  modifier onlyMinter() {
    if (!isMinter[msg.sender]) revert TLFDX_NotMinter();
    _;
  }

  constructor() ERC20("Team Locked FDX", "TLFDX") {}

  /// @notice Set minter.
  /// @param minter The address of the minter.
  /// @param allow Whether to allow the minter.
  function setMinter(address minter, bool allow) external onlyOwner {
    emit TLFDX_SetMinter(minter, isMinter[minter], allow);
    isMinter[minter] = allow;
  }

  function setTransferer(address transferor, bool isActive) external onlyOwner {
    emit TLFDX_SetTransferer(transferor, isTransferer[transferor], isActive);
    isTransferer[transferor] = isActive;
  }

  function mint(address to, uint256 amount) public onlyMinter {
    _mint(to, amount);
  }

  function burn(address from, uint256 amount) public onlyMinter {
    _burn(from, amount);
  }

  function _beforeTokenTransfer(
    address /* from */,
    address /* to */,
    uint256 /*amount*/
  ) internal virtual override {
    if (!isTransferer[msg.sender]) revert TLFDX_IsNotTransferer();
  }
}
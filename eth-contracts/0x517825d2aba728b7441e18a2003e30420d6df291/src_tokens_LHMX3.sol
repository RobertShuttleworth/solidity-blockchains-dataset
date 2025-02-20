// SPDX-License-Identifier: MIT
pragma solidity 0.8.18;

import { ERC20 } from "./lib_openzeppelin-contracts_contracts_token_ERC20_ERC20.sol";
import { Ownable } from "./lib_openzeppelin-contracts_contracts_access_Ownable.sol";

contract LHMX3 is ERC20, Ownable {
  mapping(address => bool) public isTransferer;
  mapping(address => bool) public isMinter;

  // Events
  event LHMX_SetMinter(address minter, bool prevAllow, bool newAllow);
  event LHMX_SetTransferer(address transferor, bool prevAllow, bool newAllow);

  // Errors
  error LHMX_NotMinter();
  error LHMX_IsNotTransferer();

  modifier onlyMinter() {
    if (!isMinter[msg.sender]) revert LHMX_NotMinter();
    _;
  }

  constructor() ERC20("Locked HMX 3", "LHMX 3") {}

  /// @notice Set minter.
  /// @param minter The address of the minter.
  /// @param allow Whether to allow the minter.
  function setMinter(address minter, bool allow) external onlyOwner {
    emit LHMX_SetMinter(minter, isMinter[minter], allow);
    isMinter[minter] = allow;
  }

  function setTransferer(address transferor, bool isActive) external onlyOwner {
    emit LHMX_SetTransferer(transferor, isTransferer[transferor], isActive);
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
    if (!isTransferer[msg.sender]) revert LHMX_IsNotTransferer();
  }
}
// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.20;

import "./lib_openzeppelin-contracts_contracts_token_ERC20_IERC20.sol";
import "./lib_openzeppelin-contracts_contracts_utils_Pausable.sol";
import "./lib_openzeppelin-contracts_contracts_access_AccessControl.sol";

contract OverTheCounter is Pausable, AccessControl {
  bytes32 public constant PAUSER_ROLE = keccak256("PAUSER_ROLE");
  IERC20 public immutable token;

  event Deposited(address indexed account, uint256 value);
  event Withdrawn(address indexed reciever, uint256 amount);

  constructor(IERC20 _token, address _admin) {
    token = _token;
    _grantRole(DEFAULT_ADMIN_ROLE, _admin);
    _grantRole(PAUSER_ROLE, _admin);
  }

  function deposit(uint256 amount) external whenNotPaused {
    token.transferFrom(msg.sender, address(this), amount);

    emit Deposited(msg.sender, amount);
  }

  function withdraw(address receiver, uint256 amount) external onlyRole(DEFAULT_ADMIN_ROLE) {
    token.transfer(receiver, amount);

    emit Withdrawn(receiver, amount);
  }
}
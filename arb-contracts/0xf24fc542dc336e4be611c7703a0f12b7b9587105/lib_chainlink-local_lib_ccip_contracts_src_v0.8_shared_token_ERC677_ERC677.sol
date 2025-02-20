// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import {IERC677} from "./lib_chainlink-local_lib_ccip_contracts_src_v0.8_shared_token_ERC677_IERC677.sol";
import {IERC677Receiver} from "./lib_chainlink-local_lib_ccip_contracts_src_v0.8_shared_interfaces_IERC677Receiver.sol";

import {ERC20} from "./lib_chainlink-local_lib_ccip_contracts_src_v0.8_vendor_openzeppelin-solidity_v4.8.3_contracts_token_ERC20_ERC20.sol";

contract ERC677 is IERC677, ERC20 {
  constructor(string memory name, string memory symbol) ERC20(name, symbol) {}

  /// @inheritdoc IERC677
  function transferAndCall(address to, uint256 amount, bytes memory data) public returns (bool success) {
    super.transfer(to, amount);
    emit Transfer(msg.sender, to, amount, data);
    if (to.code.length > 0) {
      IERC677Receiver(to).onTokenTransfer(msg.sender, amount, data);
    }
    return true;
  }
}
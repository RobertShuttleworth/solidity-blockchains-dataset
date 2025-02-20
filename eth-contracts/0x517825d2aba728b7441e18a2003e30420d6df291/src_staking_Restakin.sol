// SPDX-License-Identifier: WTF
pragma solidity 0.8.18;

import { Ownable } from "./lib_openzeppelin-contracts_contracts_access_Ownable.sol";
import { EsHMX } from "./src_tokens_EsHMX.sol";
import { IHMXStaking } from "./src_staking_interfaces_IHMXStaking.sol";

contract Restakin is Ownable {
  IHMXStaking public hmxStaking;
  EsHMX public esHMX;

  event Restake(address indexed user, uint256 amount);

  constructor(IHMXStaking hmxStaking_, EsHMX esHMX_) {
    hmxStaking = hmxStaking_;
    esHMX = esHMX_;
  }

  function execMany(address[] calldata users) external onlyOwner {
    require(esHMX.isTransferrer(address(this)), "!transferer");

    uint256 esHMXBalance = 0;
    for (uint256 i = 0; i < users.length; i++) {
      esHMXBalance = esHMX.balanceOf(users[i]);
      esHMX.transferFrom(users[i], address(this), esHMXBalance);
      hmxStaking.deposit(users[i], address(esHMX), esHMXBalance);
      emit Restake(users[i], esHMXBalance);
    }
  }
}
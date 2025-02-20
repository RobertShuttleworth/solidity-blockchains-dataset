// SPDX-License-Identifier: MIT
pragma solidity 0.8.18;

import { OFTV2 } from "./lib_layer-zero-example_contracts_token_oft_v2_OFTV2.sol";
import { Transfer as TransferLib } from "./src_libraries_Transfer.sol";

contract RemoteYbUSDB is OFTV2 {
  constructor(address _layerZeroEndpoint) OFTV2("ybUSDB", "ybUSDB", 6, _layerZeroEndpoint) {}

  function recoverToken(address _token, address _to, uint256 _amount) external onlyOwner {
    TransferLib.nativeOrToken(_token, _to, _amount);
  }
}
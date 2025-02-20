// SPDX-License-Identifier: MIT
pragma solidity 0.8.18;

import { OFTV2 } from "./lib_layer-zero-example_contracts_token_oft_v2_OFTV2.sol";

contract RemoteFDX is OFTV2 {
  constructor(
    address _layerZeroEndpoint,
    uint8 _sharedDecimals
  ) OFTV2("FDX", "FDX", _sharedDecimals, _layerZeroEndpoint) {}
}
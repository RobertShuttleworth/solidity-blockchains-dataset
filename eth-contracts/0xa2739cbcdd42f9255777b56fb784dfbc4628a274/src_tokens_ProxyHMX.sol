// SPDX-License-Identifier: MIT
pragma solidity 0.8.18;

import { ProxyOFTV2 } from "./lib_layer-zero-example_contracts_token_oft_v2_ProxyOFTV2.sol";

contract ProxyHMX is ProxyOFTV2 {
  constructor(
    address _token,
    uint8 _sharedDecimals,
    address _lzEndpoint
  ) ProxyOFTV2(_token, _sharedDecimals, _lzEndpoint) {}
}
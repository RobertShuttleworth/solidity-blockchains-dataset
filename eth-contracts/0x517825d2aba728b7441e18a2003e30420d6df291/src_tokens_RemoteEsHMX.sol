// SPDX-License-Identifier: BUSL-1.1
// This code is made available under the terms and conditions of the Business Source License 1.1 (BUSL-1.1).
// The act of publishing this code is driven by the aim to promote transparency and facilitate its utilization for educational purposes.

pragma solidity 0.8.18;

import { OFTV2 } from "./lib_layer-zero-example_contracts_token_oft_v2_OFTV2.sol";

contract RemoteEsHMX is OFTV2 {
  mapping(address => bool) public isTransferrer;

  error EsHMX_isNotTransferrer();

  constructor(address _layerZeroEndpoint) OFTV2("Escrowed HMX", "EsHMX", 6, _layerZeroEndpoint) {}

  function setTransferrer(address transferrer, bool isActive) external onlyOwner {
    isTransferrer[transferrer] = isActive;
  }

  function _transfer(address from, address to, uint256 amount) internal virtual override {
    if (!isTransferrer[msg.sender]) revert EsHMX_isNotTransferrer();

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
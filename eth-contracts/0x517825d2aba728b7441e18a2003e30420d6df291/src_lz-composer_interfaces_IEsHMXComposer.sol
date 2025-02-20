// SPDX-License-Identifier: BUSL-1.1
// This code is made available under the terms and conditions of the Business Source License 1.1 (BUSL-1.1).
// The act of publishing this code is driven by the aim to promote transparency and facilitate its utilization for educational purposes.

pragma solidity 0.8.18;

interface IEsHMXComposer {
  struct FailedRequest {
    address user;
    uint256 amount;
    bool isResolved;
  }

  event LogStakeForSuccess(address user, uint256 amount);
  event LogStakeForFailed(address user, uint256 amount);
  event LogSetProxyEsHMX(address oldProxyEsHMX, address newProxyEsHMX);

  error EsHMXComposer_Unauthorized();

  function setProxyEsHMX(address _proxyEsHMX) external;

  function stakeFor(address user, uint256 amount) external;

  function retry(uint256[] memory indexes) external;
}
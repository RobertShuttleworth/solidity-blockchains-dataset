// SPDX-License-Identifier: BUSL-1.1
// This code is made available under the terms and conditions of the Business Source License 1.1 (BUSL-1.1).
// The act of publishing this code is driven by the aim to promote transparency and facilitate its utilization for educational purposes.

pragma solidity 0.8.18;

import { OwnableUpgradeable } from "./lib_openzeppelin-contracts-upgradeable_contracts_access_OwnableUpgradeable.sol";
import { IHMXStaking } from "./src_staking_interfaces_IHMXStaking.sol";
import { IERC20Upgradeable } from "./lib_openzeppelin-contracts-upgradeable_contracts_token_ERC20_IERC20Upgradeable.sol";
import { SafeERC20Upgradeable } from "./lib_openzeppelin-contracts-upgradeable_contracts_token_ERC20_utils_SafeERC20Upgradeable.sol";
import { IEsHMXComposer } from "./src_lz-composer_interfaces_IEsHMXComposer.sol";

contract EsFDXComposer is OwnableUpgradeable, IEsHMXComposer {
  using SafeERC20Upgradeable for IERC20Upgradeable;

  IHMXStaking public hmxStaking;
  IERC20Upgradeable public esHMX;
  FailedRequest[] public failedRequests;
  address public proxyEsHMX;

  modifier onlyProxyEsHMX() {
    if (msg.sender != proxyEsHMX) revert EsHMXComposer_Unauthorized();
    _;
  }

  function initialize(address _hmxStaking, address _esHMX) external initializer {
    OwnableUpgradeable.__Ownable_init();

    hmxStaking = IHMXStaking(_hmxStaking);
    esHMX = IERC20Upgradeable(_esHMX);

    esHMX.approve(address(hmxStaking), type(uint256).max);
  }

  function setProxyEsHMX(address _proxyEsHMX) external onlyOwner {
    emit LogSetProxyEsHMX(proxyEsHMX, _proxyEsHMX);

    proxyEsHMX = _proxyEsHMX;
  }

  function stakeFor(address user, uint256 amount) external onlyProxyEsHMX {
    esHMX.safeTransferFrom(msg.sender, address(this), amount);
    try hmxStaking.deposit(user, address(esHMX), amount) {
      // Execution succeeded
      emit LogStakeForSuccess(user, amount);
    } catch Error(string memory /*errMsg*/) {
      _handleFailure(user, amount);
    } catch Panic(uint /*errorCode*/) {
      _handleFailure(user, amount);
    } catch (bytes memory /*errMsg*/) {
      _handleFailure(user, amount);
    }
  }

  function _handleFailure(address user, uint256 amount) internal {
    failedRequests.push(FailedRequest({ user: user, amount: amount, isResolved: false }));
    emit LogStakeForFailed(user, amount);
  }

  function retry(uint256[] memory indexes) external onlyOwner {
    uint256 index;
    for (uint256 i = 0; i < indexes.length; ) {
      index = indexes[i];
      hmxStaking.deposit(failedRequests[index].user, address(esHMX), failedRequests[index].amount);

      failedRequests[index].isResolved = true;

      unchecked {
        ++i;
      }
    }
  }
}
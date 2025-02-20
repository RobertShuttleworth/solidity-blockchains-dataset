/*
    SPDX-License-Identifier: Apache-2.0
    Copyright 2023 Reddit, Inc
    Licensed under the Apache License, Version 2.0 (the "License");
    you may not use this file except in compliance with the License.
    You may obtain a copy of the License at
    http://www.apache.org/licenses/LICENSE-2.0
    Unless required by applicable law or agreed to in writing, software
    distributed under the License is distributed on an "AS IS" BASIS,
    WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
    See the License for the specific language governing permissions and
    limitations under the License.
*/
pragma solidity ^0.8.9;

import "./openzeppelin_contracts_token_ERC20_utils_SafeERC20.sol";
import "./openzeppelin_contracts_security_ReentrancyGuard.sol";
import "./openzeppelin_contracts_access_Ownable.sol";
import "./contracts_GlobalConfig.sol";

error Splitter__ZeroAddress();
error Splitter__TokenIsAuthorized_WrongMethodCalled();
error Splitter__CannotRenounceOwnership();
error Splitter__NotConfigOwner();

/**
 * @title Splitter
 * @notice Contract that receives all NFT royalties (via EIP-2981) and further splits it between creator and reddit.
 * @dev owner is creator address.
 */
contract Splitter is ReentrancyGuard, Ownable {
  using SafeERC20 for IERC20;

  /// @notice Withdrawal of native currency is failed
  event NativeWithdrawalFailed(address to, bytes errorData);
  /// @notice Withdrawal of ERC20 token is failed
  event ERC20WithdrawalFailed(address to, address token, bytes errorData);
  /// @notice Config is updated
  event ConfigUpdated(address current, address previous, address newConfigOwner);

  // @dev address of smart contract that stores global configuration
  GlobalConfig public config;

  modifier onlyConfigOwner() {
    if (_msgSender() != config.owner()) {
      revert Splitter__NotConfigOwner();
    }
    _;
  }

  constructor(address _config, address _creator) {
    _setConfig(_config);
    _transferOwnership(_creator); // set creator as the owner.
  }

  /**
   * @notice withdraw all authorized tokens and optionally native currency (Matic)
   * @param withdrawNativeToo - bool to tell if contract should withdraw and transfer MATIC
   */
  function withdraw(bool withdrawNativeToo) external nonReentrant {
    if (withdrawNativeToo)
      _withdrawNativeCurrency();
    _withdrawERC20s();
  }

  /**
   * @notice withdraw royalties in native currency only (Matic)
   */
  function withdrawNative() external nonReentrant {
    _withdrawNativeCurrency();
  }

  /** 
  * @notice withdraw royalties in a specific token.
  * @dev splits for authorized tokens and sends everything to creator for unauthorized.
  */
  function withdrawToken(IERC20 token) external nonReentrant {
    if (config.authorizedERC20(address(token))) {
      _withdrawERC20Split(token);
    } else {
      _withdrawERC20Creator(token);
    }
  }

  /// @notice withdraw royalties in a token that is unauthorized for reddit. Creator (owner) gets all the balance.
  /// @dev throws error if token is actually authorized.
  function withdrawUnauthorizedToken(IERC20 token) external {
    if (config.authorizedERC20(address(token))) {
      revert Splitter__TokenIsAuthorized_WrongMethodCalled();
    }
    _withdrawERC20Creator(token);
  }

  /// @notice update config address
  function setConfig(address newConfig) external onlyConfigOwner {
    _setConfig(newConfig);
  }

  function _withdrawNativeCurrency() internal {
    uint256 half = _split(address(this).balance);

    // send creator (owner) and reddit their respective shares.
    // failures are logged but not reverting to make sure
    // withdrawals can't be blocked, the failing party may be penalised 
    if (half > 0) {
      (bool sent, bytes memory retData) = owner().call{value: half}("");
      if (!sent) {
        emit NativeWithdrawalFailed(owner(), retData);
      }
      try config.redditRoyalty() returns (address redditRoyalty) {
        (sent, retData) = redditRoyalty.call{value: half}("");
        if (!sent) { 
          emit NativeWithdrawalFailed(redditRoyalty, retData);
        }
      } catch {
        emit NativeWithdrawalFailed(address(0), bytes("config.redditRoyalty() reverted"));
      }      
    }
  }

  /// @dev safeTransfer throws if transfer fails.
  function _withdrawERC20s() internal {
    address [] memory authorizedERC20s = config.authorizedERC20sArray();
    uint length = authorizedERC20s.length;
    for (uint i = 0; i < length; ++i) { // post fix annotation saves gas
      IERC20 token = IERC20(authorizedERC20s[i]);
      _withdrawERC20Split(token);
    }
  }

  /// @notice Split a given amount into halfs - reddit's share and creator's share.
  /// @dev if amount is odd, 1 will be left over in the contract
  function _split(uint256 amount) internal pure returns (uint256 half) {
    return amount >> 1;
  }

  /// @notice Withdraw particular ERC20 token by splitting Reddit/creator shares.
  function _withdrawERC20Split(IERC20 token) internal {
    uint256 half = _split(token.balanceOf(address(this)));

    // send creator and reddit their respective shares.
    if (half > 0) {
      (bool ok, bytes memory errorData) = _transferERC20(token, owner(), half);
      if (!ok) {
         emit ERC20WithdrawalFailed(owner(), address(token), errorData);
      }
      try config.redditRoyalty() returns (address redditRoyalty) {
        (ok, errorData) = _transferERC20(token, redditRoyalty, half);
        if (!ok) {
          emit ERC20WithdrawalFailed(redditRoyalty, address(token), errorData);
        }
      } catch {
        emit ERC20WithdrawalFailed(address(0), address(token), bytes("config.redditRoyalty() reverted"));
      }      
    }
  }

  /// @notice Withdraw particular ERC20 token to creator only.
  function _withdrawERC20Creator(IERC20 token) internal {
    uint256 amount = token.balanceOf(address(this));
    if (amount > 0) {
      token.safeTransfer(owner(), amount);
    }
  }

  /// @notice Transfer token with handling both false result and revert
  function _transferERC20(IERC20 token, address to, uint256 amount) internal returns(bool success, bytes memory errorData) {
    try token.transfer(to, amount) returns (bool ok) {
      return (ok, "");
    } catch (bytes memory data) {
      return (false, data);
    } 
  }

  function _setConfig(address newConfigAddr) internal {
    if (newConfigAddr == address(0)) {
      revert Splitter__ZeroAddress();
    }
    GlobalConfig newConfig = GlobalConfig(newConfigAddr);
    emit ConfigUpdated(newConfigAddr, address(config), newConfig.owner());
    config = newConfig;
  }

  receive() external payable {}

  /// @dev Ownership renouncing is prohibited
  function renounceOwnership() public override pure {
    revert Splitter__CannotRenounceOwnership();
  }
}
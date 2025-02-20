// SPDX-License-Identifier: LZBL-1.2
// Taken from https://github.com/LayerZero-Labs/LayerZero-v2/blob/982c549236622c6bb9eaa6c65afcf1e0e559b624/protocol/contracts/libs/Transfer.sol
// Modified `pragma solidity ^0.8.20` to `pragma solidity 0.8.18` for compatibility without chaging the codes

pragma solidity 0.8.18;

import { SafeERC20 } from "./lib_openzeppelin-contracts_contracts_token_ERC20_utils_SafeERC20.sol";
import { IERC20 } from "./lib_openzeppelin-contracts_contracts_token_ERC20_IERC20.sol";

library Transfer {
  using SafeERC20 for IERC20;

  address internal constant ADDRESS_ZERO = address(0);

  error Transfer_NativeFailed(address _to, uint256 _value);
  error Transfer_ToAddressIsZero();

  function native(address _to, uint256 _value) internal {
    if (_to == ADDRESS_ZERO) revert Transfer_ToAddressIsZero();
    (bool success, ) = _to.call{ value: _value }("");
    if (!success) revert Transfer_NativeFailed(_to, _value);
  }

  function token(address _token, address _to, uint256 _value) internal {
    if (_to == ADDRESS_ZERO) revert Transfer_ToAddressIsZero();
    IERC20(_token).safeTransfer(_to, _value);
  }

  function nativeOrToken(address _token, address _to, uint256 _value) internal {
    if (_token == ADDRESS_ZERO) {
      native(_to, _value);
    } else {
      token(_token, _to, _value);
    }
  }
}
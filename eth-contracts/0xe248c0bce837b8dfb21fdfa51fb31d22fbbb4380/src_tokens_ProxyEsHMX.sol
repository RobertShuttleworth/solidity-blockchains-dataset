// SPDX-License-Identifier: MIT
pragma solidity 0.8.18;

import { ProxyOFTV2 } from "./lib_layer-zero-example_contracts_token_oft_v2_ProxyOFTV2.sol";
import { Transfer as TransferLib } from "./src_libraries_Transfer.sol";
import { IERC20 } from "./lib_openzeppelin-contracts_contracts_token_ERC20_extensions_IERC20Metadata.sol";
import { SafeERC20 } from "./lib_openzeppelin-contracts_contracts_token_ERC20_utils_SafeERC20.sol";
import { EsHMXComposer } from "./src_lz-composer_EsHMXComposer.sol";

contract ProxyEsHMX is ProxyOFTV2 {
  using SafeERC20 for IERC20;

  EsHMXComposer public esHMXComposer;

  event LogSetEsHMXComposer(address oldComposer, address newComposer);

  constructor(
    address _token,
    address _lzEndpoint,
    address _esHMXComposer
  ) ProxyOFTV2(_token, 6, _lzEndpoint) {
    esHMXComposer = EsHMXComposer(_esHMXComposer);

    IERC20(_token).approve(address(esHMXComposer), type(uint256).max);
  }

  function setEsHMXComposer(address _newComposer) external onlyOwner {
    emit LogSetEsHMXComposer(address(esHMXComposer), _newComposer);
    esHMXComposer = EsHMXComposer(_newComposer);

    IERC20(innerToken).approve(address(esHMXComposer), type(uint256).max);
  }

  function _creditTo(
    uint16,
    address _toAddress,
    uint _amount
  ) internal virtual override returns (uint) {
    outboundAmount -= _amount;

    // tokens are already in this contract, so no need to transfer
    if (_toAddress == address(this)) {
      return _amount;
    }

    esHMXComposer.stakeFor(_toAddress, _amount);

    return _amount;
  }

  function recoverToken(address _token, address _to, uint256 _amount) external onlyOwner {
    TransferLib.nativeOrToken(_token, _to, _amount);
  }
}
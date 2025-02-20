// SPDX-License-Identifier: GPL

pragma solidity 0.8.9;

import "./contracts_libs_app_Auth.sol";
import "./contracts_interfaces_IAddressBook.sol";

import './openzeppelin_contracts_token_ERC20_ERC20.sol';
import './contracts_libs_uniswap-core_contracts_FixedPoint96.sol';
import './contracts_libs_uniswap-core_contracts_FullMath.sol';
import './contracts_libs_uniswap-core_contracts_interfaces_IUniswapV3Pool.sol';
import './contracts_libs_uniswap-core_contracts_interfaces_IUniswapV3Factory.sol';

abstract contract BaseContract is Auth {
  using FullMath for uint;

  uint constant DECIMAL12 = 1e12;
  function init() virtual internal {
    Auth.init(msg.sender);
  }

  function __BaseContract_init(address _mn) internal {
    Auth.init(_mn);
  }

  function convertDecimal18ToDecimal6(uint _amount) internal pure returns (uint) {
    return _amount / DECIMAL12;
  }

  function getTokenPrice(address _poolAddress, uint _tokenInDecimals) internal view returns (uint256 price) {
    IUniswapV3Pool pool = IUniswapV3Pool(_poolAddress);
    (uint160 sqrtPriceX96,,,,,,) =  pool.slot0();
    uint256 numerator1 = uint256(sqrtPriceX96) * uint256(sqrtPriceX96);
    uint256 numerator2 = 10 ** _tokenInDecimals;
    return FullMath.mulDiv(numerator1, numerator2, 1 << 192);
  }
}
// SPDX-License-Identifier: MIT
pragma solidity 0.8.18;

import { IUniswapFactory } from "./src_staking_interfaces_IUniswapFactory.sol";
import { IUniswapV3Pool } from "./src_staking_interfaces_IUniswapV3Pool.sol";
import { INonfungiblePositionManager } from "./src_staking_interfaces_INonfungiblePositionManager.sol";
import { UniswapV3PoolAddress } from "./src_staking_libraries_UniswapV3PoolAddress.sol";

library NFTPositionInfo {
  function getPositionInfo(
    IUniswapFactory _factory,
    INonfungiblePositionManager _nonfungiblePositionManager,
    uint256 _tokenId
  )
    internal
    view
    returns (IUniswapV3Pool _pool, int24 _tickLower, int24 _tickUpper, uint128 _liquidity)
  {
    address _token0;
    address _token1;
    uint24 _fee;
    (
      ,
      ,
      _token0,
      _token1,
      _fee,
      _tickLower,
      _tickUpper,
      _liquidity,
      ,
      ,
      ,

    ) = _nonfungiblePositionManager.positions(_tokenId);

    _pool = IUniswapV3Pool(
      UniswapV3PoolAddress.computeAddress(
        address(_factory),
        UniswapV3PoolAddress.PoolKey({ token0: _token0, token1: _token1, fee: _fee })
      )
    );
  }
}
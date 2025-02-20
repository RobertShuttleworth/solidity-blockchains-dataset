// SPDX-License-Identifier: None
pragma solidity ^0.8.18;

import {IBaseAlcorOptionCore} from "./contracts_interfaces_IBaseAlcorOptionCore.sol";

import {AlcorUniswapExchange} from "./contracts_libraries_combo-pools_AlcorUniswapExchange.sol";
import {VanillaOptionPool} from "./contracts_libraries_combo-pools_VanillaOptionPool.sol";
import {LPPosition} from "./contracts_libraries_LPPosition.sol";
interface IVALM is IBaseAlcorOptionCore{
    event OptionExpired(uint256 price);

    event AlcorSwap(
        address indexed owner,
        int256 amount0,
        int256 amount1, 
        uint256 currentAssetPrice
    );
    event AlcorUpdatePosition(
        address indexed owner,
        int24 tickLower,
        int24 tickUpper,
        uint128 newLiquidity
    );
  
    // function mint(
    //     LPPosition.Key memory lpPositionKey,
    //     uint128 amount
    // ) external returns (uint256 amount0Delta, uint256 amount1Delta);

    function mint(
        LPPosition.Key[] memory lpPositionKeys, 
        uint128[] memory amounts, 
        AlcorUniswapExchange.SwapParams memory swapParams
    ) external returns (uint256 amountToTransfer0, uint256 amountToTransfer1);

    function burn(
        LPPosition.Key[] memory lpPositionKeys,
        AlcorUniswapExchange.SwapParams memory swapParams
    ) external returns (uint256 amount0ToTransfer, uint256 amount1ToTransfer);

    function swap(
        // address owner,
        VanillaOptionPool.Key memory optionPoolKey,
        bool zeroForOne,
        int256 amountSpecified,
        uint160 sqrtPriceLimitX96,
        AlcorUniswapExchange.SwapParams memory swapParams
    ) external returns (int256 amount0ToTransfer, int256 amount1ToTransfer);


}
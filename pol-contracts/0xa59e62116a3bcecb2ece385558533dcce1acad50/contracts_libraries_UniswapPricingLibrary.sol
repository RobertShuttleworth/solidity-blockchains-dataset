pragma solidity >=0.8.0 <0.9.0;
// SPDX-License-Identifier: MIT

 

import {IUniswapPricingLibrary} from "./contracts_interfaces_IUniswapPricingLibrary.sol";

import "./openzeppelin_contracts_utils_math_Math.sol";

 
import "./openzeppelin_contracts-upgradeable_utils_structs_EnumerableSetUpgradeable.sol";

// Libraries
import { MathUpgradeable } from "./openzeppelin_contracts-upgradeable_utils_math_MathUpgradeable.sol";
import "./openzeppelin_contracts-upgradeable_token_ERC20_extensions_IERC20MetadataUpgradeable.sol";
import "./openzeppelin_contracts-upgradeable_utils_cryptography_MerkleProofUpgradeable.sol";

import "./contracts_interfaces_uniswap_IUniswapV3Pool.sol"; 

import "./contracts_libraries_uniswap_TickMath.sol";
import "./contracts_libraries_uniswap_FixedPoint96.sol";
import "./contracts_libraries_uniswap_FullMath.sol";
 
 
import "./openzeppelin_contracts_token_ERC20_IERC20.sol";

import "./openzeppelin_contracts-upgradeable_access_OwnableUpgradeable.sol";


/*

Only do decimal expansion if it is an ERC20   not anything else !! 

*/

library UniswapPricingLibrary  
{
    
    uint256 constant STANDARD_EXPANSION_FACTOR = 1e18;

    function getUniswapPriceRatioForPoolRoutes(
        IUniswapPricingLibrary.PoolRouteConfig[] memory poolRoutes
    ) public view returns (uint256 priceRatio) {
        require(poolRoutes.length <= 2, "invalid pool routes length");

        if (poolRoutes.length == 2) {
            uint256 pool0PriceRatio = getUniswapPriceRatioForPool(
                poolRoutes[0]
            );

            uint256 pool1PriceRatio = getUniswapPriceRatioForPool(
                poolRoutes[1]
            );

            return
                FullMath.mulDiv(
                    pool0PriceRatio,
                    pool1PriceRatio,
                    STANDARD_EXPANSION_FACTOR
                );
        } else if (poolRoutes.length == 1) {
            return getUniswapPriceRatioForPool(poolRoutes[0]);
        }

        //else return 0
    }

    /*
        The resultant product is expanded by STANDARD_EXPANSION_FACTOR one time 
    */
    function getUniswapPriceRatioForPool(
        IUniswapPricingLibrary.PoolRouteConfig memory _poolRouteConfig
    ) public view returns (uint256 priceRatio) {
        uint160 sqrtPriceX96 = getSqrtTwapX96(
            _poolRouteConfig.pool,
            _poolRouteConfig.twapInterval
        );

        //This is the token 1 per token 0 price
        uint256 sqrtPrice = FullMath.mulDiv(
            sqrtPriceX96,
            STANDARD_EXPANSION_FACTOR,
            2**96
        );

        uint256 sqrtPriceInverse = (STANDARD_EXPANSION_FACTOR *
            STANDARD_EXPANSION_FACTOR) / sqrtPrice;

        uint256 price = _poolRouteConfig.zeroForOne
            ? sqrtPrice * sqrtPrice
            : sqrtPriceInverse * sqrtPriceInverse;

        return price / STANDARD_EXPANSION_FACTOR;
    }



    function getSqrtTwapX96(address uniswapV3Pool, uint32 twapInterval)
        internal
        view
        returns (uint160 sqrtPriceX96)
    {
        if (twapInterval == 0) {
            // return the current price if twapInterval == 0
            (sqrtPriceX96, , , , , , ) = IUniswapV3Pool(uniswapV3Pool).slot0();
        } else {
            uint32[] memory secondsAgos = new uint32[](2);
            secondsAgos[0] = twapInterval + 1; // from (before)
            secondsAgos[1] = 1; // one block prior

            (int56[] memory tickCumulatives, ) = IUniswapV3Pool(uniswapV3Pool)
                .observe(secondsAgos);

            // tick(imprecise as it's an integer) to price
            sqrtPriceX96 = TickMath.getSqrtRatioAtTick(
                int24(
                    (tickCumulatives[1] - tickCumulatives[0]) /
                        int32(twapInterval)
                )
            );
        }
    }

    function getPriceX96FromSqrtPriceX96(uint160 sqrtPriceX96)
        internal
        pure
        returns (uint256 priceX96)
    {   

        
        return FullMath.mulDiv(sqrtPriceX96, sqrtPriceX96, FixedPoint96.Q96);
    }

}
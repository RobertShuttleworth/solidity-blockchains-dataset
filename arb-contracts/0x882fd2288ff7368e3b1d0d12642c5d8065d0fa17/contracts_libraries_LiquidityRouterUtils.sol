// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

import {FullMath} from "./contracts_libraries_FullMath.sol";
import {FixedPoint96} from "./contracts_libraries_FixedPoint96.sol";
import {LiquidityAmounts} from "./contracts_libraries_LiquidityAmounts.sol";
import {TickMath} from "./contracts_libraries_TickMath.sol";

library LiquidityRouterUtils {
    using FullMath for uint256;

    function calculateAdjustedTick(uint160 sqrtPriceX96, int256 percent, int24 tickSpacing) internal pure returns(int24 calculatedTick) {

        if (percent > 0) {
            uint160 adjustment = uint160((uint256(sqrtPriceX96) * uint256(percent)) / 1e6);
            sqrtPriceX96 += adjustment;
        } else {
            uint160 adjustment = uint160((uint256(sqrtPriceX96) * uint256(-percent)) / 1e6);
            sqrtPriceX96 -= adjustment;
        }

        return tickRoundUp(TickMath.getTickAtSqrtRatio(sqrtPriceX96), tickSpacing);
    }

    function tickRoundUp(int24 tick, int24 tickSpacing) internal pure returns (int24) 
    {
        int24 remainder = tick % tickSpacing;
        if (remainder == 0) {
            return tick;
        }
        
        int24 lowerMultiple = tick - remainder;  
        int24 upperMultiple = lowerMultiple + tickSpacing; 

        return (tick - lowerMultiple < upperMultiple - tick) ? lowerMultiple : upperMultiple;
    }


    function checkTicksPercents(int256 lowerPercent, int256 upperPercent) internal pure returns(bool) {
        if ((lowerPercent < 0 && upperPercent < 0) && (abs(lowerPercent) < abs(upperPercent))) {
            return false;
        } else if ((lowerPercent > 0 && upperPercent > 0) && (abs(lowerPercent) > abs(upperPercent))) {
            return false; 
        } else if (lowerPercent > 0 && upperPercent < 0) {
            return false;
        }
        return true;
    }

    function abs(int256 x) internal pure returns (int256) {
        return  int256(x >= 0 ? x : -x);
    }

    function calculateLiquidityAmount(
        uint160 sqrtRatioAX96,
        uint160 sqrtRatioBX96,
        uint160 sqrtRatioX96,
        uint256 totalAmount
    ) internal pure returns (uint128 liquidity, uint256) {
        if (sqrtRatioAX96 > sqrtRatioBX96)
            (sqrtRatioAX96, sqrtRatioBX96) = (sqrtRatioBX96, sqrtRatioAX96);

        if (sqrtRatioX96 <= sqrtRatioAX96) {
            liquidity = LiquidityAmounts.getLiquidityForAmount0(
                sqrtRatioAX96,
                sqrtRatioBX96,
                totalAmount
            );
            return(liquidity, totalAmount);

        } else if (sqrtRatioX96 < sqrtRatioBX96) {
            uint256 numerator1 = uint256(sqrtRatioBX96 - sqrtRatioX96) * FixedPoint96.Q96;
            numerator1 = FullMath.mulDivRoundingUp(numerator1, 1 ether, uint256(sqrtRatioBX96) * sqrtRatioX96);

            uint256 numerator2 = FullMath.mulDivRoundingUp(uint256(sqrtRatioX96 - sqrtRatioAX96), 1 ether,FixedPoint96.Q96);
            liquidity = uint128(FullMath.mulDiv(totalAmount, 1 ether, numerator1 + numerator2));

            (uint256 amount0, uint256 amount1) = LiquidityAmounts.getAmountsForLiquidity(sqrtRatioX96, sqrtRatioAX96, sqrtRatioBX96, liquidity);
            
            return(liquidity, amount0+amount1);
        } else {
            liquidity = LiquidityAmounts.getLiquidityForAmount1(
                sqrtRatioAX96,
                sqrtRatioBX96,
                totalAmount
            );
            return(liquidity, totalAmount);
        }
    }
}
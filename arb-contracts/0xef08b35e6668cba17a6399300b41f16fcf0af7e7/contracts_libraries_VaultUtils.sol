// SPDX-License-Identifier: None
pragma solidity ^0.8.18;

import {FullMath} from "./contracts_libraries_FullMath.sol";
import {FixedPoint96} from "./contracts_libraries_FixedPoint96.sol";
import {LiquidityAmounts} from "./contracts_libraries_LiquidityAmounts.sol";

library VaultUtils {
    using FullMath for uint256;

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

    // @dev both strike and priceAtExpiry must be expressed in terms of 1e18
    function calculateVanillaCallPayoffInAsset(
        bool isLong,
        uint256 strike,
        uint256 priceAtExpiry,
        uint8 token1Decimals
    ) internal pure returns (uint256 payoff) {
        if (priceAtExpiry > strike) {
            payoff = FullMath.mulDiv(
                (priceAtExpiry - strike),
                10 ** token1Decimals,
                priceAtExpiry
            );
        } else {
            payoff = 0;
        }
        if (isLong) {
            return payoff;
        } else {
            return 10 ** token1Decimals - payoff;
        }
    }


    function calculatePayoffAmount(
        int256 userOptionBalance,
        uint256 strike,
        uint256 priceAtExpiry,
        uint8 token1Decimals
    ) internal pure returns (uint256 amount) {
        if (userOptionBalance < 0) {
            amount = uint256(-userOptionBalance).mulDiv(
                calculateVanillaCallPayoffInAsset(
                    false,
                    strike,
                    priceAtExpiry,
                    token1Decimals
                ),
                10 ** token1Decimals
            );
        } else {
            amount = uint256(userOptionBalance).mulDiv(
                calculateVanillaCallPayoffInAsset(
                    true,
                    strike,
                    priceAtExpiry,
                    token1Decimals
                ),
                10 ** token1Decimals
            );
        }
        return amount;
    }
    function getCollateralAfterUpdateUserOptionBalance(
        int256 userOptionBalance,
        int256 userOptionBalanceDelta
    ) internal pure returns (uint256 amount1ToTransfer) {
        if (userOptionBalanceDelta < 0) {
            if (
                userOptionBalance < 0 &&
                userOptionBalance - userOptionBalanceDelta > 0
            ) {
                amount1ToTransfer = uint256(-userOptionBalance);
            } else if (
                userOptionBalance < 0 &&
                userOptionBalance - userOptionBalanceDelta < 0
            ) {
                amount1ToTransfer = uint256(-userOptionBalanceDelta);
            }
        } else {
            if (
                userOptionBalance > 0 &&
                userOptionBalance - userOptionBalanceDelta < 0
            ) {
                amount1ToTransfer = uint256(userOptionBalance);
            } else if (
                userOptionBalance > 0 &&
                userOptionBalance - userOptionBalanceDelta > 0
            ) {
                amount1ToTransfer = uint256(userOptionBalanceDelta);
            }
        }
        return (amount1ToTransfer);
    }
 
}
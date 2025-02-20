// SPDX-License-Identifier: GPL-3.0-only
pragma solidity 0.8.16;

import "./contracts_extensions_IPriceGetterProtocol.sol";
import "./contracts_IPriceGetter.sol";
import "./contracts_lib_UtilityLibrary.sol";
import "./contracts_extensions_Curve_interfaces_ICurveTwocryptoOptimized.sol";
import "./contracts_extensions_Curve_interfaces_ICurveTwocryptoFactory.sol";

contract PriceGetterCurve is IPriceGetterProtocol {
    // ========== Get Token Prices ==========

    function getTokenPrice(
        address token,
        address factory,
        PriceGetterParams memory params
    ) public view override returns (uint256 price) {
        ICurveTwocryptoFactory curveFactory = ICurveTwocryptoFactory(factory);

        uint256 nativePrice = params.mainPriceGetter.getNativePrice(IPriceGetter.Protocol.Curve, address(curveFactory));
        if (token == params.wrappedNative.tokenAddress) {
            /// @dev Returning high total balance for wrappedNative to heavily weight value.
            return nativePrice;
        }

        uint256 priceAddition;
        uint256 foundPoolTokens;

        try curveFactory.find_pool_for_coins(token, params.wrappedNative.tokenAddress) returns (address _pool) {
            ICurveTwocryptoOptimized pool = ICurveTwocryptoOptimized(_pool);
            uint256 native_dy;
            if (pool.coins(0) == params.wrappedNative.tokenAddress) {
                native_dy = pool.get_dy(0, 1, params.nativeLiquidityThreshold);
            } else {
                native_dy = pool.get_dy(1, 0, params.nativeLiquidityThreshold);
            }
            native_dy = ((1e36 / native_dy) * 1e18) / params.nativeLiquidityThreshold;

            priceAddition += (native_dy * nativePrice) / 1e18;
            foundPoolTokens++;
        } catch {}

        for (uint256 i = 0; i < params.stableUsdTokens.length; i++) {
            IPriceGetter.TokenAndDecimals memory stableUsdToken = params.stableUsdTokens[i];
            try curveFactory.find_pool_for_coins(token, stableUsdToken.tokenAddress) returns (address _pool) {
                ICurveTwocryptoOptimized pool = ICurveTwocryptoOptimized(_pool);
                uint256 native_dy;
                if (pool.coins(0) == params.wrappedNative.tokenAddress) {
                    native_dy = pool.get_dy(0, 1, 10 ** stableUsdToken.decimals);
                } else {
                    native_dy = pool.get_dy(1, 0, 10 ** stableUsdToken.decimals);
                }
                native_dy = (1e36 / native_dy);

                uint256 stableUsdPrice = params.mainPriceGetter.getOraclePriceNormalized(stableUsdToken.tokenAddress);
                if (stableUsdPrice > 0) {
                    priceAddition += (native_dy * stableUsdPrice) / 1e18;
                } else {
                    priceAddition += native_dy;
                }
                foundPoolTokens++;
            } catch {}
        }

        price = priceAddition / foundPoolTokens;
    }

    // ========== LP PRICE ==========

    function getLPPrice(
        address lp,
        address factory,
        PriceGetterParams memory params
    ) public view override returns (uint256 price) {
        //if not a LP, handle as a standard token
        try ICurveTwocryptoOptimized(lp).lp_price() returns (uint256 _lpPrice) {
            return _lpPrice;
        } catch {
            /// @dev If the pair is not a valid LP, return the price of the token
            uint256 lpPrice = getTokenPrice(lp, factory, params);
            return lpPrice;
        }
    }

    // ========== NATIVE PRICE ==========

    function getNativePrice(
        address factory,
        PriceGetterParams memory params
    ) public view override returns (uint256 price) {}

    // ========== INTERNAL FUNCTIONS ==========

    /**
     * @dev Get normalized reserves for a given token pair from the ApeSwap Factory contract, specifying decimals.
     * @param factoryCurve The address of the Curve factory.
     * @param tokenA The address of the first token in the pair.
     * @param tokenB The address of the second token in the pair.
     * @param decimalsA The number of decimals for the first token in the pair.
     * @param decimalsB The number of decimals for the second token in the pair.
     * @return normalizedReserveA The normalized reserve of the first token in the pair.
     * @return normalizedReserveB The normalized reserve of the second token in the pair.
     */
    function _getNormalizedReservesFromFactoryCurve_Decimals(
        ICurveTwocryptoFactory factoryCurve,
        address tokenA,
        address tokenB,
        uint8 decimalsA,
        uint8 decimalsB
    ) internal view returns (uint256 normalizedReserveA, uint256 normalizedReserveB) {
        address pairAddress = factoryCurve.find_pool_for_coins(tokenA, tokenB);
        if (pairAddress == address(0)) {
            return (0, 0);
        }
        return _getNormalizedReservesFromPair_Decimals(pairAddress, tokenA, tokenB, decimalsA, decimalsB);
    }

    /**
     * @dev This internal function takes in a pair address, two token addresses (tokenA and tokenB), and their respective decimals.
     * It returns the normalized reserves for each token in the pair.
     *
     * This function uses the IApePair interface to get the current reserves of the given token pair
     * If successful, it returns the normalized reserves for each token in the pair by calling _normalize() on
     * the reserve values. The order of the returned normalized reserve values depends on the lexicographic ordering
     * of tokenA and tokenB.
     *
     * @param pair Address of the liquidity pool contract representing the token pair
     * @param tokenA Address of one of the tokens in the pair. Assumed to be a valid address in the pair to save on gas.
     * @param tokenB Address of the other token in the pair. Assumed to be a valid address in the pair to save on gas.
     * @param decimalsA The number of decimals for tokenA
     * @param decimalsB The number of decimals for tokenB
     * @return normalizedReserveA The normalized reserve value for tokenA
     * @return normalizedReserveB The normalized reserve value for tokenB
     */
    function _getNormalizedReservesFromPair_Decimals(
        address pair,
        address tokenA,
        address tokenB,
        uint8 decimalsA,
        uint8 decimalsB
    ) internal view returns (uint256 normalizedReserveA, uint256 normalizedReserveB) {
        (bool success, bytes memory returnData) = pair.staticcall(abi.encodeWithSignature("getReserves()"));

        if (success) {
            try this.decodeReservesWithLP(returnData) returns (uint112 reserve0, uint112 reserve1, uint32) {
                if (UtilityLibrary._isSorted(tokenA, tokenB)) {
                    return (
                        UtilityLibrary._normalize(reserve0, decimalsA),
                        UtilityLibrary._normalize(reserve1, decimalsB)
                    );
                } else {
                    return (
                        UtilityLibrary._normalize(reserve1, decimalsA),
                        UtilityLibrary._normalize(reserve0, decimalsB)
                    );
                }
            } catch {
                (success, returnData) = pair.staticcall(abi.encodeWithSignature("getFictiveReserves()"));
                try this.decodeReservesWithoutLP(returnData) returns (uint256 reserve0, uint256 reserve1) {
                    if (UtilityLibrary._isSorted(tokenA, tokenB)) {
                        return (
                            UtilityLibrary._normalize(reserve0, decimalsA),
                            UtilityLibrary._normalize(reserve1, decimalsB)
                        );
                    } else {
                        return (
                            UtilityLibrary._normalize(reserve1, decimalsA),
                            UtilityLibrary._normalize(reserve0, decimalsB)
                        );
                    }
                } catch {
                    return (0, 0);
                }
            }
        } else {
            return (0, 0);
        }
    }

    function decodeReservesWithLP(
        bytes memory data
    ) public pure returns (uint112 reserve0, uint112 reserve1, uint32 lp) {
        return abi.decode(data, (uint112, uint112, uint32));
    }

    function decodeReservesWithoutLP(bytes memory data) public pure returns (uint256 reserve0, uint256 reserve1) {
        return abi.decode(data, (uint256, uint256));
    }
}
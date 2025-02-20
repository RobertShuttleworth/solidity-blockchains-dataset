// SPDX-License-Identifier: MIT
/**
                                                    
 ███▄ ▄███▓ ▄▄▄     ▄▄▄█████▓ ██░ ██ 
▓██▒▀█▀ ██▒▒████▄   ▓  ██▒ ▓▒▓██░ ██▒
▓██    ▓██░▒██  ▀█▄ ▒ ▓██░ ▒░▒██▀▀██░
▒██    ▒██ ░██▄▄▄▄██░ ▓██▓ ░ ░▓█ ░██ 
▒██▒   ░██▒ ▓█   ▓██▒ ▒██▒ ░ ░▓█▒░██▓
░ ▒░   ░  ░ ▒▒   ▓▒█░ ▒ ░░    ▒ ░░▒░▒
░  ░      ░  ▒   ▒▒ ░   ░     ▒ ░▒░ ░
░      ░     ░   ▒    ░       ░  ░░ ░
       ░         ░  ░         ░  ░  ░
                                                                                                                                                                                                             
 @title GluedMath
 @author (Original Uniswap Labs). Glue Implementation by @BasedToschi
 @notice Library for advanced fixed-point math operations.
 @dev Implements multiplication and division with overflow protection and precision retention.

*/

pragma solidity ^0.8.28;

library GluedMath {
    /**
     * @notice Performs a multiply-divide operation with full precision.
     * @dev Calculates floor(a * b / denominator) with full precision, using 512-bit intermediate values.
     * Throws if the result overflows a uint256 or if the denominator is zero.
     * @param a The multiplicand.
     * @param b The multiplier.
     * @param denominator The divisor.
     * @return result The result of the operation.
     */
    function md512(uint256 a, uint256 b, uint256 denominator) internal pure returns (uint256 result) {
        unchecked {
            uint256 prod0; 
            uint256 prod1;
            assembly {
                let mm := mulmod(a, b, not(0))
                prod0 := mul(a, b)
                prod1 := sub(sub(mm, prod0), lt(mm, prod0))
            }

            require(denominator > prod1, "GluedMath: denominator is zero or result overflows");

            if (prod1 == 0) {
                assembly {
                    result := div(prod0, denominator)
                }
                return result;
            }

            uint256 remainder;
            assembly {
                remainder := mulmod(a, b, denominator)
                prod1 := sub(prod1, gt(remainder, prod0))
                prod0 := sub(prod0, remainder)
            }

            uint256 twos = (0 - denominator) & denominator;
            assembly {
                denominator := div(denominator, twos)
                prod0 := div(prod0, twos)
            }

            uint256 inv = (3 * denominator) ^ 2;
            inv *= 2 - denominator * inv; // inverse mod 2^8
            inv *= 2 - denominator * inv; // inverse mod 2^16
            inv *= 2 - denominator * inv; // inverse mod 2^32
            inv *= 2 - denominator * inv; // inverse mod 2^64
            inv *= 2 - denominator * inv; // inverse mod 2^128
            inv *= 2 - denominator * inv; // inverse mod 2^256

            result = prod0 * inv;
            return result;
        }
    }

    /**
     * @notice Performs a multiply-divide operation with full precision and rounding up.
     * @dev Calculates ceil(a * b / denominator) with full precision, using 512-bit intermediate values.
     * Throws if the result overflows a uint256 or if the denominator is zero.
     * @param a The multiplicand.
     * @param b The multiplier.
     * @param denominator The divisor.
     * @return result The result of the operation, rounded up to the nearest integer.
     */
    function md512Up(uint256 a, uint256 b, uint256 denominator) internal pure returns (uint256 result) {
        unchecked {
            result = md512(a, b, denominator);
            if (mulmod(a, b, denominator) > 0) {
                require(result < type(uint256).max, "GluedMath: result overflows");
                result++;
            }
        }
    }
}
// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

import "./contracts_helpers_ERC20Helper.sol";

interface UniswapV3Pool {
    /// @notice Swap token0 for token1, or token1 for token0
    /// @dev The caller of this method receives a callback in the form of IUniswapV3SwapCallback#uniswapV3SwapCallback
    /// @param recipient The address to receive the output of the swap
    /// @param zeroForOne The direction of the swap, true for token0 to token1, false for token1 to token0
    /// @param amountSpecified The amount of the swap, which implicitly configures the swap as exact input (positive), or exact output (negative)
    /// @param sqrtPriceLimitX96 The Q64.96 sqrt price limit. If zero for one, the price cannot be less than this
    /// value after the swap. If one for zero, the price cannot be greater than this value after the swap
    /// @param data Any data to be passed through to the callback
    /// @return amount0Delta The delta of the balance of token0 of the pool, exact when negative, minimum when positive
    /// @return amount1Delta The delta of the balance of token1 of the pool, exact when negative, minimum when positive
    function swap(
        address recipient,
        bool zeroForOne,
        int256 amountSpecified,
        uint160 sqrtPriceLimitX96,
        bytes calldata data
    ) external returns (int256 amount0Delta, int256 amount1Delta);
}

contract UniswapV3Modeler is ERC20Helper {
    function uniV3Swap(
        UniswapV3Pool pool,
        address seller,
        address recipient,
        address sellToken,
        bool zeroForOne,
        uint256 sellAmount,
        uint160 sqrtPriceLimitX96
    ) external returns (uint256) {
        int256 amountSpecified = int256(sellAmount);
        bytes memory callbackData = abi.encode(seller, sellToken);
        (int256 amount0Delta, int256 amount1Delta) =
            pool.swap(recipient, zeroForOne, amountSpecified, sqrtPriceLimitX96, callbackData);
        return uint256(-(zeroForOne ? amount1Delta : amount0Delta));
    }

    function uniswapV3SwapCallback(int256 amount0Delta, int256 amount1Delta, bytes calldata data) external {
        // sell token used in the swap
        (, address sellTokenAddress) = abi.decode(data, (address, address));

        uint256 sellAmount;
        if (amount0Delta < 0) {
            // token 1 for token 0
            sellAmount = uint256(amount1Delta);
        } else {
            // token 0 for token 1
            sellAmount = uint256(amount0Delta);
        }

        safeTransfer(sellTokenAddress, msg.sender, sellAmount);
    }
}
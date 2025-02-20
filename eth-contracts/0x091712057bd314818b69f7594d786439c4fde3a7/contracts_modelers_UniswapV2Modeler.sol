// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

import "./contracts_helpers_ERC20Helper.sol";

interface IUniswapV2Pair {
    function swap(uint256 amount0Out, uint256 amount1Out, address to, bytes calldata data) external;
    function getReserves() external view returns (uint112 reserve0, uint112 reserve1, uint32 blockTimestampLast);
}

contract UniswapV2Modeler is ERC20Helper {
    function uniV2Swap(
        address pair,
        address sender,
        address recipient,
        address sellToken,
        address buyToken,
        uint256 sellAmount,
        bool zeroForOne
    ) external returns (uint256 buyAmount) {
        uint256 startBalance = getBalance(buyToken, recipient);

        IUniswapV2Pair pool = IUniswapV2Pair(pair);

        (uint256 reserve0, uint256 reserve1,) = pool.getReserves();
        uint256 amountInWithFee = sellAmount * 997;
        uint256 amount0Out;
        uint256 amount1Out;

        if (zeroForOne) {
            amount1Out = (amountInWithFee * reserve1) / (reserve0 * 1000 + amountInWithFee);
        } else {
            amount0Out = (amountInWithFee * reserve0) / (reserve1 * 1000 + amountInWithFee);
        }

        safeTransferFrom(
            sellToken,
            sender,
            pair, // uniswap v2 pool address
            sellAmount // exact sell amount
        );

        pool.swap(amount0Out, amount1Out, recipient, new bytes(0));
        uint256 endBalance = getBalance(buyToken, recipient);
        buyAmount = endBalance - startBalance;
    }
}
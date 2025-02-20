// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

interface ISwap {
    struct ExactInputParams {
        uint160[] path;
        address sender;
        address recipient;
        uint256 deadline;
        uint256 amountIn;
        uint256 amountOutMin;
        uint160 referralId;
    }

    struct ExactOutputParams {
        uint160[] path;
        address sender;
        address recipient;
        uint256 deadline;
        uint256 amountOut;
        uint256 amountInMax;
        uint160 referralId;
    }

    struct AddLiquidityParams {
        address sender;
        address recipient;
        uint160 id0;
        uint160 id1;
        uint256 amount0Desired;
        uint256 amount1Desired;
        uint256 amount0Min;
        uint256 amount1Min;
        uint256 deadline;
    }

    struct RemoveLiquidityParams {
        address sender;
        address recipient;
        uint256 poolId;
        uint256 liquidity;
        uint256 amount0Min;
        uint256 amount1Min;
        uint256 deadline;
    }

    event AddLiquidity(
        address indexed sender, 
        uint160 id0, 
        uint160 id1, 
        uint256 amount0, 
        uint256 amount1, 
        address indexed to
    );
    event RemoveLiquidity(
        address indexed sender, 
        uint256 liquidity, 
        uint160 id0, 
        uint160 id1, 
        uint256 amount0, 
        uint256 amount1, 
        address indexed to
    );

    event Swap(
        address indexed recipient,
        uint160 idIn,
        uint160 idOut,
        uint256 amountIn,
        uint256 amountOut
    );
}
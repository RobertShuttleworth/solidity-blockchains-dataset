// SPDX-License-Identifier: None
pragma solidity ^0.8.18;

import {SafeERC20} from "./openzeppelin_contracts_token_ERC20_utils_SafeERC20.sol";
import {ERC20} from "./openzeppelin_contracts_token_ERC20_ERC20.sol";
import {ISwapRouter} from "./contracts_interfaces_ISwapRouter.sol";
import {IV3Pool} from "./contracts_interfaces_v3-pool_IV3Pool.sol";

library AlcorUniswapExchange{
    using SafeERC20 for ERC20;
    
    error notApprovedToken();
    error notEnoughAmountForSwap();

    struct SwapParams {
        address token;
        uint24 fee;
        address recipient;
        uint256 deadline;
        uint256 amount;
        uint160 sqrtPriceLimitX96;
    } 
    
    function swapTokensThroughUniswap(
        address owner,
        ISwapRouter uniswapRouter, 
        IV3Pool v3Pool,
        address assetToken, 
        int256 swapAmount,
        SwapParams memory swapParams
    ) internal {
        if (!v3Pool.approvedForPayment(swapParams.token))
                revert notApprovedToken();

        if (swapAmount < 0) {
         
            ERC20(swapParams.token).safeTransferFrom(
                owner,
                address(this),
                swapParams.amount
            );
            ERC20(swapParams.token).safeIncreaseAllowance(
                address(uniswapRouter),
                swapParams.amount
            );

            ISwapRouter.ExactOutputSingleParams
                memory exactOutputSingleParams = ISwapRouter
                    .ExactOutputSingleParams({
                        tokenIn: swapParams.token,
                        tokenOut: assetToken,
                        fee: swapParams.fee,
                        recipient: address(v3Pool),
                        deadline: block.timestamp,
                        amountOut: uint256(-swapAmount),
                        amountInMaximum: swapParams.amount,
                        sqrtPriceLimitX96: swapParams.sqrtPriceLimitX96
                    });

            uint256 balanceBefore = ERC20(assetToken).balanceOf(address(v3Pool));
            uint256 amountIn = uniswapRouter.exactOutputSingle(
                exactOutputSingleParams
            );
            uint256 balanceAfter = ERC20(assetToken).balanceOf(address(v3Pool));

            if (
                balanceBefore + uint256(-swapAmount) !=
                balanceAfter
            ) revert notEnoughAmountForSwap();

            if (amountIn < swapParams.amount){
                ERC20(swapParams.token).safeDecreaseAllowance(
                    address(uniswapRouter),
                    swapParams.amount - amountIn
                );
                ERC20(swapParams.token).safeTransfer(
                    owner,
                    swapParams.amount - amountIn
                );
            }
        } else if(swapAmount > 0){
            v3Pool.transferFromPool(assetToken, address(this),  uint256(swapAmount));

            ERC20(assetToken).safeIncreaseAllowance(
                address(uniswapRouter),
                uint256(swapAmount)
            );

            ISwapRouter.ExactInputSingleParams
                memory ExactInputSingleParams = ISwapRouter
                    .ExactInputSingleParams({
                        tokenIn: assetToken,
                        tokenOut: swapParams.token,
                        fee: swapParams.fee,
                        recipient: owner,
                        deadline: block.timestamp,
                        amountIn: uint256(swapAmount),
                        amountOutMinimum: swapParams.amount,
                        sqrtPriceLimitX96: swapParams.sqrtPriceLimitX96
                    });

            uint256 balanceBefore = ERC20(assetToken).balanceOf(address(this));
            uniswapRouter.exactInputSingle(
                ExactInputSingleParams
            );
            uint256 balanceAfter = ERC20(assetToken).balanceOf(address(this));

            if (
                balanceAfter + uint256(swapAmount) >
                balanceBefore
            ){
                ERC20(assetToken).safeDecreaseAllowance(
                    address(uniswapRouter),
                    balanceAfter + uint256(swapAmount) - balanceBefore 
                );
                ERC20(assetToken).safeTransfer(
                    owner,
                    balanceAfter + uint256(swapAmount) - balanceBefore 
                );
             
            }
        }
    }
}
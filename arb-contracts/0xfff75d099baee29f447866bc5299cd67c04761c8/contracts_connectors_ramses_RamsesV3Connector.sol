// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import { IERC20 } from "./lib_openzeppelin-contracts_contracts_token_ERC20_IERC20.sol";
import { SwapParams } from "./contracts_structs_LiquidityStructs.sol";
import { SwapParams } from "./contracts_structs_LiquidityStructs.sol";
import { SwapParams } from "./contracts_structs_LiquidityStructs.sol";
import { SwapParams } from "./contracts_structs_LiquidityStructs.sol";
import { INftFarmConnector, Farm, NftPosition } from "./contracts_interfaces_INftFarmConnector.sol";
import "./contracts_interfaces_external_ramses_IRamsesNonfungiblePositionManager.sol";
import { ISwapRouter } from "./contracts_interfaces_external_uniswap_ISwapRouter.sol";
import { ISwapRouter } from "./contracts_interfaces_external_uniswap_ISwapRouter.sol";
import { ISwapRouter } from "./contracts_interfaces_external_uniswap_ISwapRouter.sol";
import { UniswapV3Connector, NftAddLiquidity } from "./contracts_connectors_UniswapV3Connector.sol";
import { INonfungiblePositionManager } from "./contracts_interfaces_external_uniswap_INonfungiblePositionManager.sol";

struct RamsesV3SwapExtraData {
    address pool;
    bytes path;
}

contract RamsesV3Connector is UniswapV3Connector {
    function swapExactTokensForTokens(
        SwapParams memory swap
    ) external payable override {
        RamsesV3SwapExtraData memory extraData =
            abi.decode(swap.extraData, (RamsesV3SwapExtraData));

        IERC20(swap.tokenIn).approve(extraData.pool, swap.amountIn);

        ISwapRouter.ExactInputParams memory params = ISwapRouter
            .ExactInputParams({
            path: extraData.path,
            recipient: address(this),
            deadline: block.timestamp + 1,
            amountIn: swap.amountIn,
            amountOutMinimum: swap.minAmountOut
        });

        ISwapRouter(swap.router).exactInput(params);
    }

    function claim(
        NftPosition calldata position,
        address[] memory rewardTokens,
        uint128 amount0Max,
        uint128 amount1Max,
        bytes calldata // extraData
    ) external payable override {
        IRamsesNonfungiblePositionManager(address(position.nft)).getReward(
            position.tokenId, rewardTokens
        );
        if (amount0Max > 0 || amount1Max > 0) {
            IRamsesNonfungiblePositionManager.CollectParams memory params =
            IRamsesNonfungiblePositionManager.CollectParams({
                tokenId: position.tokenId,
                recipient: address(this),
                amount0Max: amount0Max,
                amount1Max: amount1Max
            });
            IRamsesNonfungiblePositionManager(address(position.nft)).collect(
                params
            );
        }
    }

    function _mint(
        NftAddLiquidity memory addLiquidityParams
    ) internal virtual override {
        IRamsesNonfungiblePositionManager.MintParams memory params =
        IRamsesNonfungiblePositionManager.MintParams({
            token0: addLiquidityParams.pool.token0,
            token1: addLiquidityParams.pool.token1,
            fee: addLiquidityParams.pool.fee,
            tickLower: addLiquidityParams.tickLower,
            tickUpper: addLiquidityParams.tickUpper,
            amount0Desired: addLiquidityParams.amount0Desired,
            amount1Desired: addLiquidityParams.amount1Desired,
            amount0Min: addLiquidityParams.amount0Min,
            amount1Min: addLiquidityParams.amount1Min,
            recipient: address(this),
            deadline: block.timestamp + 1,
            veRamTokenId: 0
        });

        IRamsesNonfungiblePositionManager(address(addLiquidityParams.nft)).mint(
            params
        );
    }
}
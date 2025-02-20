// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import { IERC20 } from "./lib_openzeppelin-contracts_contracts_token_ERC20_IERC20.sol";
import { INonfungiblePositionManager } from "./contracts_interfaces_external_uniswap_INonfungiblePositionManager.sol";
import { ISwapRouter } from "./contracts_interfaces_external_uniswap_ISwapRouter.sol";

import { INftFarmConnector } from "./contracts_interfaces_INftFarmConnector.sol";
import { INftLiquidityConnector } from "./contracts_interfaces_INftLiquidityConnector.sol";
import { SwapParams } from "./contracts_structs_LiquidityStructs.sol";
import { SwapParams } from "./contracts_structs_LiquidityStructs.sol";
import { SwapParams } from "./contracts_structs_LiquidityStructs.sol";
import { SwapParams } from "./contracts_structs_LiquidityStructs.sol";
import { NftAddLiquidity, NftRemoveLiquidity, Pool } from "./contracts_structs_NftLiquidityStructs.sol";
import { Farm } from "./contracts_structs_FarmStrategyStructs.sol";
import { NftPosition } from "./contracts_structs_NftFarmStrategyStructs.sol";

struct UniswapV3SwapExtraData {
    address pool;
    bytes path;
}

contract UniswapV3Connector is INftLiquidityConnector, INftFarmConnector {
    error InvalidParameters();

    function addLiquidity(
        NftAddLiquidity memory addLiquidityParams
    ) external payable override {
        if (addLiquidityParams.tokenId == 0) {
            _mint(addLiquidityParams);
        } else {
            _increase_liquidity(addLiquidityParams);
        }
    }

    function _get_current_liquidity(
        NftRemoveLiquidity memory removeLiquidityParams
    ) internal view virtual returns (uint128 currentLiquidity) {
        (,,,,,,, currentLiquidity,,,,) =
            removeLiquidityParams.nft.positions(removeLiquidityParams.tokenId);
    }

    function removeLiquidity(
        NftRemoveLiquidity memory removeLiquidityParams
    ) external override {
        uint128 currentLiquidity;
        if (removeLiquidityParams.liquidity == type(uint128).max) {
            currentLiquidity = _get_current_liquidity(removeLiquidityParams);
            removeLiquidityParams.liquidity = currentLiquidity;
        }

        if (removeLiquidityParams.liquidity == 0) {
            revert InvalidParameters();
        }

        _decrease_liquidity(removeLiquidityParams);

        _collect(removeLiquidityParams);

        currentLiquidity = _get_current_liquidity(removeLiquidityParams);
        if (currentLiquidity == 0) {
            removeLiquidityParams.nft.burn(removeLiquidityParams.tokenId);
        }
    }

    function swapExactTokensForTokens(
        SwapParams memory swap
    ) external payable virtual override {
        UniswapV3SwapExtraData memory extraData =
            abi.decode(swap.extraData, (UniswapV3SwapExtraData));

        IERC20(swap.tokenIn).approve(address(extraData.pool), swap.amountIn);

        ISwapRouter(swap.router).exactInput(
            ISwapRouter.ExactInputParams({
                path: extraData.path,
                recipient: address(this),
                deadline: block.timestamp + 1,
                amountIn: swap.amountIn,
                amountOutMinimum: swap.minAmountOut
            })
        );
    }

    function depositExistingNft(
        NftPosition calldata, // position,
        bytes calldata // extraData
    ) external payable virtual override { }

    function withdrawNft(
        NftPosition calldata, // position,
        bytes calldata // extraData
    ) external payable virtual override { }

    function claim(
        NftPosition calldata position,
        address[] memory, // rewardTokens
        uint128 amount0Max,
        uint128 amount1Max,
        bytes calldata // extraData
    ) external payable virtual override {
        _claim_fees(position, amount0Max, amount1Max);
    }

    function _claim_fees(
        NftPosition calldata position,
        uint128 amount0Max,
        uint128 amount1Max
    ) internal virtual {
        if (amount0Max > 0 || amount1Max > 0) {
            INonfungiblePositionManager.CollectParams memory params =
            INonfungiblePositionManager.CollectParams({
                tokenId: position.tokenId,
                recipient: address(this),
                amount0Max: amount0Max,
                amount1Max: amount1Max
            });
            INonfungiblePositionManager(address(position.nft)).collect(params);
        }
    }

    function _mint(
        NftAddLiquidity memory addLiquidityParams
    ) internal virtual {
        addLiquidityParams.nft.mint(
            INonfungiblePositionManager.MintParams({
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
                deadline: block.timestamp + 1
            })
        );
    }

    function _increase_liquidity(
        NftAddLiquidity memory addLiquidityParams
    ) internal {
        addLiquidityParams.nft.increaseLiquidity(
            INonfungiblePositionManager.IncreaseLiquidityParams({
                tokenId: addLiquidityParams.tokenId,
                amount0Desired: addLiquidityParams.amount0Desired,
                amount1Desired: addLiquidityParams.amount1Desired,
                amount0Min: addLiquidityParams.amount0Min,
                amount1Min: addLiquidityParams.amount1Min,
                deadline: block.timestamp + 1
            })
        );
    }

    function _decrease_liquidity(
        NftRemoveLiquidity memory removeLiquidityParams
    ) internal {
        removeLiquidityParams.nft.decreaseLiquidity(
            INonfungiblePositionManager.DecreaseLiquidityParams({
                tokenId: removeLiquidityParams.tokenId,
                liquidity: removeLiquidityParams.liquidity,
                amount0Min: removeLiquidityParams.amount0Min,
                amount1Min: removeLiquidityParams.amount1Min,
                deadline: block.timestamp + 1
            })
        );
    }

    function _collect(
        NftRemoveLiquidity memory removeLiquidityParams
    ) internal {
        removeLiquidityParams.nft.collect(
            INonfungiblePositionManager.CollectParams({
                tokenId: removeLiquidityParams.tokenId,
                recipient: address(this),
                amount0Max: removeLiquidityParams.amount0Max,
                amount1Max: removeLiquidityParams.amount1Max
            })
        );
    }
}
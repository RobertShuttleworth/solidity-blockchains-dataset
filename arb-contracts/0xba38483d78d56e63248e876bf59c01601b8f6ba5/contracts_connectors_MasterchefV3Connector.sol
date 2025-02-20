// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import { IERC721Enumerable } from "./lib_openzeppelin-contracts_contracts_interfaces_IERC721Enumerable.sol";

import { Farm, NftPosition } from "./contracts_interfaces_INftFarmConnector.sol";
import { SwapParams } from "./contracts_interfaces_INftLiquidityConnector.sol";
import { INonfungiblePositionManager } from "./contracts_interfaces_external_uniswap_INonfungiblePositionManager.sol";
import { IMasterchefV3 } from "./contracts_interfaces_external_IMasterchefV3.sol";
import { UniswapV3Connector } from "./contracts_connectors_UniswapV3Connector.sol";

contract MasterchefV3Connector is UniswapV3Connector {
    error Unsupported();

    function depositExistingNft(
        NftPosition calldata position,
        bytes calldata // extraData
    ) external payable override {
        IERC721Enumerable(position.nft).safeTransferFrom(
            address(this), position.farm.stakingContract, position.tokenId
        );
    }

    function withdrawNft(
        NftPosition calldata position,
        bytes calldata // extraData
    ) external payable override {
        IMasterchefV3(position.farm.stakingContract).withdraw(
            position.tokenId, address(this)
        );
    }

    function claim(
        NftPosition calldata position,
        address[] memory, // rewardTokens
        uint128 amount0Max,
        uint128 amount1Max,
        bytes calldata // extraData
    ) external payable override {
        IMasterchefV3(position.farm.stakingContract).harvest(
            position.tokenId, address(this)
        );
        if (amount0Max > 0 || amount1Max > 0) {
            INonfungiblePositionManager.CollectParams memory params =
            INonfungiblePositionManager.CollectParams({
                tokenId: position.tokenId,
                recipient: address(this),
                amount0Max: amount0Max,
                amount1Max: amount1Max
            });
            INonfungiblePositionManager(position.farm.stakingContract).collect(
                params
            );
        }
    }

    function swapExactTokensForTokens(
        SwapParams memory
    ) external payable override {
        revert Unsupported();
    }
}
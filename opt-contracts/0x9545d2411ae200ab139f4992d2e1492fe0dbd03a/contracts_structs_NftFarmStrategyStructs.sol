// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import { IUniswapV3Pool } from "./contracts_interfaces_external_uniswap_IUniswapV3Pool.sol";
import { INonfungiblePositionManager } from "./contracts_interfaces_external_uniswap_INonfungiblePositionManager.sol";
import { NftZapIn, NftZapOut } from "./contracts_structs_NftZapStructs.sol";
import { SwapParams } from "./contracts_structs_LiquidityStructs.sol";
import { Farm } from "./contracts_structs_FarmStrategyStructs.sol";

struct NftPosition {
    Farm farm;
    INonfungiblePositionManager nft;
    uint256 tokenId;
}

struct NftIncrease {
    address[] tokensIn;
    uint256[] amountsIn;
    NftZapIn zap;
    bytes extraData;
}

struct NftDeposit {
    Farm farm;
    INonfungiblePositionManager nft;
    NftIncrease increase;
}

struct NftWithdraw {
    NftZapOut zap;
    address[] tokensOut;
    bytes extraData;
}

struct SimpleNftHarvest {
    address[] rewardTokens;
    uint128 amount0Max;
    uint128 amount1Max;
    bytes extraData;
}

struct NftHarvest {
    SimpleNftHarvest harvest;
    SwapParams[] swaps;
    address[] outputTokens;
    address[] sweepTokens;
}

struct NftCompound {
    SimpleNftHarvest harvest;
    NftZapIn zap;
}

struct NftRebalance {
    IUniswapV3Pool pool;
    NftPosition position;
    NftHarvest harvest;
    NftWithdraw withdraw;
    NftIncrease increase;
}

struct NftMove {
    IUniswapV3Pool pool;
    NftPosition position;
    NftHarvest harvest;
    NftWithdraw withdraw;
    NftDeposit deposit;
}
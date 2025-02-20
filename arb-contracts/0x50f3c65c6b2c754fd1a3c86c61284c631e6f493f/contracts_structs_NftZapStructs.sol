// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import { SwapParams } from "./contracts_structs_LiquidityStructs.sol";
import { SwapParams } from "./contracts_structs_LiquidityStructs.sol";
import { SwapParams } from "./contracts_structs_LiquidityStructs.sol";
import { NftAddLiquidity, NftRemoveLiquidity } from "./contracts_structs_NftLiquidityStructs.sol";

struct NftZapIn {
    SwapParams[] swaps;
    NftAddLiquidity addLiquidityParams;
}

struct NftZapOut {
    NftRemoveLiquidity removeLiquidityParams;
    SwapParams[] swaps;
}
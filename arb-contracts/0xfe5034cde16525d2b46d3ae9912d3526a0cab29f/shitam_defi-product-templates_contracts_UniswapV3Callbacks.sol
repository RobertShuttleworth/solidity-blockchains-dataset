// SPDX-License-Identifier: SHIFT-1.0
pragma solidity ^0.8.24;

import {NotImplemented} from "./shitam_defi-product-templates_contracts_Errors.sol";

abstract contract UniswapV3Callbacks {
    function uniswapV3SwapCallback(
        int256 amount0Delta,
        int256 amount1Delta,
        bytes calldata data
    ) external virtual {
        revert NotImplemented();
    }
    function uniswapV3MintCallback(
        uint256 amount0Owed,
        uint256 amount1Owed,
        bytes calldata data
    ) external virtual {
        revert NotImplemented();
    }
    function uniswapV3FlashCallback(
        uint256 fee0,
        uint256 fee1,
        bytes calldata data
    ) external virtual {
        revert NotImplemented();
    }
}
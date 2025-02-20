// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

/*

░██╗░░░░░░░██╗░█████╗░░█████╗░░░░░░░███████╗██╗
░██║░░██╗░░██║██╔══██╗██╔══██╗░░░░░░██╔════╝██║
░╚██╗████╗██╔╝██║░░██║██║░░██║█████╗█████╗░░██║
░░████╔═████║░██║░░██║██║░░██║╚════╝██╔══╝░░██║
░░╚██╔╝░╚██╔╝░╚█████╔╝╚█████╔╝░░░░░░██║░░░░░██║
░░░╚═╝░░░╚═╝░░░╚════╝░░╚════╝░░░░░░░╚═╝░░░░░╚═╝

*
* MIT License
* ===========
*
* Copyright (c) 2020 WooTrade
*
* Permission is hereby granted, free of charge, to any person obtaining a copy
* of this software and associated documentation files (the "Software"), to deal
* in the Software without restriction, including without limitation the rights
* to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
* copies of the Software, and to permit persons to whom the Software is
* furnished to do so, subject to the following conditions:
*
* The above copyright notice and this permission notice shall be included in all
* copies or substantial portions of the Software.
*
* THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
* IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
* FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
* AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
* LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
* OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
*/

/// @title WOOFi cross chain router interface (version 5, supporting StargateV2, 1inch and Odos).
/// @notice functions to interface with WOOFi cross chain swap, and 1inch for local swap
interface IWooCrossChainRouterV5 {
    /* ----- Structs ----- */

    struct SrcInfos {
        address fromToken;
        address bridgeToken;
        uint256 fromAmount;
        uint256 minBridgeAmount;
    }

    struct SrcExtSwapInfo {
        address swapRouter;
        bytes data;
    }

    struct DstInfos {
        uint32 dstEid;              // Dest Endpoint Id
        address bridgeToken;        // Bridge token received on Dest Chain
        address toToken;            // Final toToken on Dest Chain
        uint256 minToAmount;
        uint128 airdropNativeAmount;
        uint128 dstGasForCall;
    }

    struct DstExtSwapInfo {
        address swapRouter;
        bytes data;
    }

    /* ----- Events ----- */

    event WooCrossSwapOnSrcChain(
        uint256 indexed refId,
        address indexed sender,
        address indexed to,
        address fromToken,
        uint256 fromAmount,
        address bridgeToken,
        uint256 minBridgeAmount,
        uint256 realBridgeAmount,
        uint8 swapType,
        uint256 fee
    );

    event WooCrossSwapOnDstChain(
        uint256 indexed refId,
        address indexed sender,
        address indexed to,
        address bridgedToken,
        uint256 bridgedAmount,
        address toToken,
        address realToToken,
        uint256 minToAmount,
        uint256 realToAmount,
        uint8 swapType,
        uint256 fee
    );

    /* ----- State Variables ----- */

    function bridgeSlippage() external view returns (uint256);

    function wooCrossRouters(uint32 eid) external view returns (address wooCrossRouter);

    /* ----- Functions ----- */

    function crossSwap(
        uint256 refId,
        address payable to,
        SrcInfos memory srcInfos,
        DstInfos calldata dstInfos,
        SrcExtSwapInfo calldata srcExtSwapInfo,
        DstExtSwapInfo calldata dstExtSwapInfo
    ) external payable;

    function quoteLayerZeroFee(
        uint256 refId,
        address to,
        SrcInfos calldata srcInfos,
        DstInfos calldata dstInfos,
        DstExtSwapInfo calldata dstExtSwapInfo
    ) external view returns (uint256 nativeAmount, uint256 zroAmount);
}
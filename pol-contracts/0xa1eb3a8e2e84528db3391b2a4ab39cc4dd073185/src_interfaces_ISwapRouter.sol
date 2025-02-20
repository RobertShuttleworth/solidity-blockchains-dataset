// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity >=0.7.5;
pragma abicoder v2;

import "./src_interfaces_IV2SwapRouter.sol";
import {IV3SwapRouter} from"./IV3SwapRouter.sol";

/// @title Router token swapping functionality
/// @notice Functions for swapping tokens via Uniswap V2 and V3
interface ISwapRouter is IV2SwapRouter, IV3SwapRouter {}
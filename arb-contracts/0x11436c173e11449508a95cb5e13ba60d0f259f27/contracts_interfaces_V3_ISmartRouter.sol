// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity ^0.8.0;

import './contracts_interfaces_V3_IV2SwapRouter.sol';
import './contracts_interfaces_V3_IV3SwapRouter.sol';
import './contracts_interfaces_V3_IStableSwapRouter.sol';
import './contracts_interfaces_V3_IMulticallExtended.sol';

/// @title Router token swapping functionality
interface ISmartRouter is IV2SwapRouter, IV3SwapRouter, IStableSwapRouter, IMulticallExtended {
    function WETH9() external view returns (address);
}
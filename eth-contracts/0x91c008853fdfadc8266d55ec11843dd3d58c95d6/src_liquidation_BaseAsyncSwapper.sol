// SPDX-License-Identifier: UNLICENSED
// Copyright (c) 2023 Tokemak Foundation. All rights reserved.
pragma solidity ^0.8.24;

import { IERC20 } from "./lib_openzeppelin-contracts_contracts_token_ERC20_IERC20.sol";
import { LibAdapter } from "./src_libs_LibAdapter.sol";
import { IAsyncSwapper, SwapParams } from "./src_interfaces_liquidation_IAsyncSwapper.sol";

/**
 * @title BaseAsyncSwapper
 * @notice This contract is designed to be invoked via delegatecall. It does not implement its own reentrancy
 * protection.
 *
 * @dev WARNING: Any contract delegatecalling into this MUST implement its own ReentrancyGuard protection mechanism to
 * prevent potential reentrancy attacks.
 */
contract BaseAsyncSwapper is IAsyncSwapper {
    // solhint-disable-next-line var-name-mixedcase
    address public immutable AGGREGATOR;

    constructor(
        address aggregator
    ) {
        if (aggregator == address(0)) revert TokenAddressZero();
        AGGREGATOR = aggregator;
    }

    /// @inheritdoc IAsyncSwapper
    function swap(
        SwapParams memory swapParams
    ) public virtual returns (uint256 buyTokenAmountReceived) {
        //slither-disable-start reentrancy-events
        if (swapParams.buyTokenAddress == address(0)) revert TokenAddressZero();
        if (swapParams.sellTokenAddress == address(0)) revert TokenAddressZero();
        if (swapParams.buyAmount == 0) revert InsufficientBuyAmount();

        preSwap(swapParams);

        if (swapParams.sellAmount == 0) revert InsufficientSellAmount();

        IERC20 sellToken = IERC20(swapParams.sellTokenAddress);
        IERC20 buyToken = IERC20(swapParams.buyTokenAddress);

        // Not checking current balance of sell token as aggregator
        // will fail to pull the amount if we're too low based on the approval
        // and we also want to support the "sell entire balance" feature of some
        // aggregators where we don't know the amount ahead of time

        LibAdapter._approve(sellToken, AGGREGATOR, swapParams.sellAmount);

        uint256 buyTokenBalanceBefore = buyToken.balanceOf(address(this));

        // we don't need the returned value, we calculate the buyTokenAmountReceived ourselves
        // slither-disable-start low-level-calls,unchecked-lowlevel
        // solhint-disable-next-line avoid-low-level-calls
        (bool success,) = AGGREGATOR.call(swapParams.data);
        // slither-disable-end low-level-calls,unchecked-lowlevel

        if (!success) {
            revert SwapFailed();
        }

        uint256 buyTokenBalanceAfter = buyToken.balanceOf(address(this));
        buyTokenAmountReceived = buyTokenBalanceAfter - buyTokenBalanceBefore;

        if (buyTokenAmountReceived < swapParams.buyAmount) {
            revert InsufficientBuyAmountReceived(buyTokenAmountReceived, swapParams.buyAmount);
        }

        emit Swapped(
            swapParams.sellTokenAddress,
            swapParams.buyTokenAddress,
            swapParams.sellAmount,
            swapParams.buyAmount,
            buyTokenAmountReceived
        );

        return buyTokenAmountReceived;
        //slither-disable-end reentrancy-events
    }

    // slither-disable-start dead-code
    /// @notice Allow for custom behavior in derived contracts to occur before the swap
    function preSwap(
        SwapParams memory
    ) internal virtual { }
    // slither-disable-end dead-code
}
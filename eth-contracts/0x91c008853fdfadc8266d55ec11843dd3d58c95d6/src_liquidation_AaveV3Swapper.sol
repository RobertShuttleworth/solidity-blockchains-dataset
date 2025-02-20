// SPDX-License-Identifier: UNLICENSED
// Copyright (c) 2023 Tokemak Foundation. All rights reserved.
pragma solidity ^0.8.24;

import { Errors } from "./src_utils_Errors.sol";
import { SwapParams } from "./src_interfaces_liquidation_IAsyncSwapper.sol";
import { BaseAsyncSwapper } from "./src_liquidation_BaseAsyncSwapper.sol";
import { IATokenV3 } from "./src_interfaces_external_aave_IATokenV3.sol";
import { IAavePoolV3 } from "./src_interfaces_external_aave_IAavePoolV3.sol";

/// @notice Performs a withdraw from an Aave V3 pool before swapping the underlying the token
contract AaveV3Swapper is BaseAsyncSwapper {
    /// @notice The Aave aToken this swapper can operate on
    IATokenV3 public immutable aToken;

    /// @notice The underlying token the aToken wraps
    address public immutable underlyingToken;

    /// @notice The pool the aToken is related to
    IAavePoolV3 public immutable aavePool;

    event AmountWithdrawn(uint256);

    error NonZeroBalance(uint256);

    constructor(address aggregator, address _aToken) BaseAsyncSwapper(aggregator) {
        Errors.verifyNotZero(_aToken, "aToken");

        address ut = IATokenV3(_aToken).UNDERLYING_ASSET_ADDRESS();
        address pool = IATokenV3(_aToken).POOL();

        Errors.verifyNotZero(ut, "underlyingToken");
        Errors.verifyNotZero(pool, "pool");

        aToken = IATokenV3(_aToken);

        // slither-disable-next-line missing-zero-check
        underlyingToken = ut;
        aavePool = IAavePoolV3(pool);
    }

    /// @notice Perform a withdraw of the entire balance of aToken the contract has
    function preSwap(
        SwapParams memory
    ) internal virtual override {
        // Aave's withdraw can either mint us more, or take less, of the shares

        // Normal procedure for use of this contract is to have just transferred the aTokens
        // to the contract so that none of that extra/less mint/burn should occur.
        // We check the balance at the end to verify

        // No "min amount out" checks here. The base swapper has a sellAmount that it expects
        // which acts as the minimum check from this operation.
        uint256 amount = IAavePoolV3(aavePool).withdraw(underlyingToken, type(uint256).max, address(this));

        // slither-disable-next-line reentrancy-events
        emit AmountWithdrawn(amount);

        // We only support utilizing the full balance of token during withdraw
        // so that we don't have to handle being minted more
        uint256 bal = aToken.balanceOf(address(this));
        if (bal != 0) {
            revert NonZeroBalance(bal);
        }
    }
}
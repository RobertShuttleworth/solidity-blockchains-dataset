// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import {IERC20} from "./openzeppelin_contracts_token_ERC20_IERC20.sol";
import {SafeERC20} from "./openzeppelin_contracts_token_ERC20_utils_SafeERC20.sol";
import "./wormhole_Utils.sol";

import {HubSpokeStructs} from "./src_contracts_HubSpokeStructs.sol";

library SpokeAccountingLogic {
    using SafeERC20 for IERC20;

    error InsufficientFunds();
    error TransferFailed();
    error ZeroAddress();

    // events need to be in both library and contract to be picked up
    // see: https://ethereum.stackexchange.com/questions/11137/watching-events-defined-in-libraries
    event ReservesWithdrawn(address indexed asset, uint256 amount, address destination);
    // end events from HubSpokeEvents

    function getReserveAmount(
        HubSpokeStructs.SpokeOptimisticFinalityState storage ofState,
        address asset
    ) public view returns (uint256) {
        HubSpokeStructs.SpokeBalances storage balance = ofState.tokenBalances[toWormholeFormat(address(asset))];
        return IERC20(asset).balanceOf(address(this)) - balance.deposits - balance.creditGiven;
    }

    function withdrawReserves(
        HubSpokeStructs.SpokeOptimisticFinalityState storage ofState,
        address asset,
        uint256 amount,
        address recipient
    ) public {
        if (recipient == address(0)) {
            revert ZeroAddress();
        }

        if (asset == address(0)) {
            if (address(this).balance < amount) {
                revert InsufficientFunds();
            }
            (bool success,) = payable(recipient).call{value: amount}("");
            if (!success) {
                revert TransferFailed();
            }
        } else {
            if (amount > getReserveAmount(ofState, asset)) {
                revert InsufficientFunds();
            }
            IERC20(asset).safeTransfer(recipient, amount);
        }

        emit ReservesWithdrawn(asset, amount, recipient);
    }
}
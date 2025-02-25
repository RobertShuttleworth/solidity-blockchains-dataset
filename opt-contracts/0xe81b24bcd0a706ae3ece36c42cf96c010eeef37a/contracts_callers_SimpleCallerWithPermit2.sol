// Copyright (C) 2020 Zerion Inc. <https://zerion.io>
//
// This program is free software: you can redistribute it and/or modify
// it under the terms of the GNU General Public License as published by
// the Free Software Foundation, either version 3 of the License, or
// (at your option) any later version.
//
// This program is distributed in the hope that it will be useful,
// but WITHOUT ANY WARRANTY; without even the implied warranty of
// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
// GNU General Public License for more details.
//
// You should have received a copy of the GNU General Public License
// along with this program. If not, see <https://www.gnu.org/licenses/>.
//
// SPDX-License-Identifier: LGPL-3.0-only

pragma solidity 0.8.12;

import { Address } from "./openzeppelin_contracts_utils_Address.sol";

import { ICaller } from "./contracts_interfaces_ICaller.sol";
import { IPermit2 } from "./contracts_interfaces_IPermit2.sol";
import { Base } from "./contracts_shared_Base.sol";
import { ZeroTarget } from "./contracts_shared_Errors.sol";
import { Permit2 } from "./contracts_shared_Permit2.sol";
import { TokensHandler } from "./contracts_shared_TokensHandler.sol";

/**
 * @title Simple caller that passes through any call and forwards return tokens
 * @dev It also works in fixed outputs case, when input token overhead is refunded
 * @dev This contracts uses Permit2 contract in case of Uniswap's Universal Router usage
 */
contract SimpleCallerWithPermit2 is ICaller, TokensHandler, Permit2 {
    address internal constant ETH = 0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE;

    /**
     * @notice Sets Permit2 address for the current chain
     * @param permit2 Wrapped Ether address
     */
    constructor(address universalRouter, address permit2) Permit2(universalRouter, permit2) {
        // solhint-disable-previous-line no-empty-blocks
    }

    /**
     * @notice Main external function: decodes `callerCallData` bytes,
     *     executes external call, and returns tokens back to `msg.sender` (i.e. Router contract)
     * @param callerCallData ABI-encoded parameters:
     *     - inputToken Address of the token that should be approved to the allowance target
     *     - allowanceTarget Address to approve `inputToken` to
     *     - callTarget Address to forward the external call to
     *     - callData Call data to be used in the external call
     *     - outputToken Address of the token that should be returned
     * @dev Call target cannot be zero
     */
    function callBytes(bytes calldata callerCallData) external override {
        (
            address inputToken,
            address allowanceTarget,
            address payable callTarget,
            bytes memory callData,
            address outputToken
        ) = abi.decode(callerCallData, (address, address, address, bytes, address));
        if (callTarget == address(0)) revert ZeroTarget();

        // Approve tokens to the allowance target, call the call target
        approveAndCall(inputToken, allowanceTarget, callTarget, callData);

        // In case of non-zero input token, transfer the remaining amount back to `msg.sender`
        Base.transfer(inputToken, msg.sender, Base.getBalance(inputToken));

        // In case of non-zero output token, transfer the total balance to `msg.sender`
        Base.transfer(outputToken, msg.sender, Base.getBalance(outputToken));
    }

    /**
     * @dev Approves input tokens (if necessary) and calls the target with the provided call data
     * @dev Approval and allowance check for `address(0)` token address are skipped
     * @param inputToken Address of the token that should be approved to the allowance target
     * @param allowanceTarget Address to approve `inputToken` to
     * @param callTarget Address to forward the external call to
     * @param callData Call data for the call to the target
     */
    function approveAndCall(
        address inputToken,
        address allowanceTarget,
        address callTarget,
        bytes memory callData
    ) internal {
        uint256 amount = Base.getBalance(inputToken);
        if (inputToken == ETH) {
            Address.functionCallWithValue(
                callTarget,
                callData,
                amount,
                "SC: payable call failed w/ no reason"
            );
            return;
        }

        if (inputToken != address(0) && allowanceTarget != address(0)) {
            address permit2 = getPermit2();

            if (allowanceTarget == getUniversalRouter()) {
                Base.safeApproveMax(inputToken, permit2, amount);
                IPermit2(permit2).approve(
                    inputToken,
                    allowanceTarget,
                    type(uint160).max,
                    type(uint48).max
                );
            } else {
                Base.safeApproveMax(inputToken, allowanceTarget, amount);
            }
        }

        Address.functionCall(callTarget, callData, "SC: call failed w/ no reason");
    }
}
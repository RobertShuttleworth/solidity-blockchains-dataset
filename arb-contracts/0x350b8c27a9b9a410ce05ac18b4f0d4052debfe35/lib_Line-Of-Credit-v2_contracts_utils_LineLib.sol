// SPDX-License-Identifier: GPL-3.0
// Copyright: https://github.com/credit-cooperative/Line-Of-Credit-v2/blob/master/COPYRIGHT.md

pragma solidity 0.8.25;

import {IERC20} from "./lib_openzeppelin-contracts_contracts_token_ERC20_IERC20.sol";
import {SafeERC20} from "./lib_openzeppelin-contracts_contracts_token_ERC20_utils_SafeERC20.sol";
import {Denominations} from "./lib_chainlink_contracts_src_v0.8_Denominations.sol";

/**
 * @title   - LineLib
 * @author  - Credit Cooperative
 * @notice  - Core logic used by LineOfCredit contract for sending and receiving tokens/ETH.
 */
library LineLib {
    using SafeERC20 for IERC20;

    error EthSentWithERC20();
    error TransferFailed();
    error SendingEthFailed();
    error RefundEthFailed();
    error BadToken();

    enum STATUS {
        UNINITIALIZED,
        ACTIVE,
        LIQUIDATABLE,
        REPAID,
        INSOLVENT,
        ABORTED
    }

    /**
     * @notice - Send ETH or ERC20 token from this contract to an external contract
     * @param token - address of token to send out. Denominations.ETH for raw ETH
     * @param receiver - address to send tokens to
     * @param amount - amount of tokens to send
     */
    function sendOutTokenOrETH(address token, address receiver, uint256 amount) internal {
        // both branches revert if call failed
        if (token != Denominations.ETH) {
            // ERC20
            IERC20(token).safeTransfer(receiver, amount);
        } else {
            // ETH
            _safeTransferFunds(receiver, amount);
        }
    }

    /**
     * @notice - Receive ETH or ERC20 token at this contract from an external contract
     * @dev    - If the sender overpays, the difference will be refunded to the sender
     * @param token - address of token to receive. Denominations.ETH for raw ETH
     * @param sender - address that is sendingtokens/ETH
     * @param amount - amount of tokens to send
     */
    function receiveTokenOrETH(address token, address sender, uint256 amount) external {
        if (token != Denominations.ETH) {
            // ERC20
            if (msg.value != 0) {
                revert EthSentWithERC20();
            }
            IERC20(token).safeTransferFrom(sender, address(this), amount);
        } else {
            // ETH
            if (msg.value != amount) {
                revert TransferFailed();
            }
        }
    }

    /**
     * @notice - Helper function to get current balance of this contract for ERC20 or ETH
     * @param token - address of token to check. Denominations.ETH for raw ETH
     */
    function getBalance(address token) internal view returns (uint256) {
        if (token == address(0)) return 0;
        return token != Denominations.ETH ? IERC20(token).balanceOf(address(this)) : address(this).balance;
    }

    /**
     * @notice  - Helper function to safely transfer Eth using native call
     * @dev     - Errors should be handled in the calling function
     * @param recipient - address of the recipient
     * @param value - value to be sent (in wei)
     */
    function _safeTransferFunds(address recipient, uint256 value) internal returns (bool success) {
        (success,) = payable(recipient).call{value: value}("");
        if (!success) revert SendingEthFailed();
    }

    /**
     * @notice  - Helper function to safely approve a contract to spend tokens in the line
     * @dev     - Errors should be handled in the calling function
     * @param token - address of the token being approved
     * @param spender - the address of the address that is being approved to spend
     * @param amount - amount being approved
     */
    function _forceApprove(address token, address spender, uint256 amount) internal {
        IERC20(token).forceApprove(spender, amount);
    }
}
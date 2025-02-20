// SPDX-License-Identifier: GPL-3.0-or-later

pragma solidity 0.7.6;
pragma abicoder v2;

import "./openzeppelin_contracts_utils_Address.sol";
import "./openzeppelin_contracts_math_SafeMath.sol";
import "./contracts_interfaces_IAdapter.sol";

import "./contracts_lib_LibERC20Adapter.sol";

/// @title  Swap aggregation adapter
/// @notice Adapter that performs swap and sends the swaps amonts to the relevant parties. Used in regular swaps.
/// @author MetaDexa.io
contract SwapAggregatorAdapter is IAdapter {

    using Address for address;
    using SafeMath for uint256;

    /// @dev swap adapter data
    struct SwapAggregatorData {
        IERC20 tokenFrom;
        IERC20 tokenTo;
        uint256 amountFrom;
        uint256 amountToMin;
        address aggregator;
        bytes aggregatorData;
    }

    function adapt(AdapterContext calldata context)
    external
    payable
    override
    returns (bytes4 success)
    {
        SwapAggregatorData memory data = abi.decode(context.data, (SwapAggregatorData));

        // 1. check allowance and approve (even for WETH)
        if (!LibERC20Adapter.isTokenETH(data.tokenFrom)) {
            TransferHelper.safeApprove(
                address(data.tokenFrom), data.aggregator, data.amountFrom
            );
        }

        // balance before
        uint256 recipientTokenToBalanceBefore = LibERC20Adapter.getTokenBalanceOf(
            data.tokenTo, context.recipient
        );

        // 2. call the aggregator with aggregator data
        data.aggregator.functionCallWithValue(data.aggregatorData, msg.value);

        // 3. Transfer remaining balance of tokenTo to recipient
        uint256 outputTokenAmount = _transfer(data.tokenTo, context.recipient);

        {

            // balance after
            uint256 recipientTokenToBalanceAfter = LibERC20Adapter.getTokenBalanceOf(
                data.tokenTo, context.recipient
            );

            // check conditions
            require(recipientTokenToBalanceAfter >= recipientTokenToBalanceBefore, 'SAA_NEG');

            uint256 diffRecipientToken = recipientTokenToBalanceAfter.sub(recipientTokenToBalanceBefore);
            outputTokenAmount = outputTokenAmount > diffRecipientToken ? outputTokenAmount : diffRecipientToken;
            require(outputTokenAmount >= data.amountToMin, 'SAA_MIN');

        }

        // 4. Transfer remaining balance of tokenFrom back to the sender
        _transfer(data.tokenFrom, context.sender);

        return LibERC20Adapter.TRANSFORMER_SUCCESS;
    }

    function _transfer(IERC20 tokenToTransfer, address payable recipient) internal returns (uint256 amountOut)  {

        amountOut = LibERC20Adapter.getTokenBalanceOf(tokenToTransfer, address(this));
        if (amountOut > 0 && recipient != address(this)) {
            LibERC20Adapter.adapterTransfer(tokenToTransfer, recipient, amountOut);
        }
    }
}
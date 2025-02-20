// SPDX-License-Identifier: GPL-3.0-or-later

pragma solidity 0.7.6;
pragma abicoder v2;

import "./openzeppelin_contracts_utils_Address.sol";
import "./openzeppelin_contracts_math_SafeMath.sol";
import "./contracts_interfaces_IAdapter.sol";

import "./contracts_lib_LibERC20Adapter.sol";

/// @title  Gasless swap aggregation adapter
/// @notice Sends a portion of the swapped amounts to the validator. Used for gasless swaps.
/// @author MetaDexa.io
contract GaslessSwapAdapter is IAdapter {

    using Address for address;
    using SafeMath for uint256;

    /// @dev swap adapter data
    struct GaslessSwapData {
        IERC20 tokenFrom;
        IERC20 tokenTo;
        uint256 amountFrom;
        uint256 amountToMin;
        IERC20 paymentToken;
        uint256 paymentFees;
        address validator;
        address aggregator;
        bytes aggregatorData;
    }

    function adapt(AdapterContext calldata context)
    external
    payable
    override
    returns (bytes4 success)
    {
        GaslessSwapData memory data = abi.decode(context.data, (GaslessSwapData));

        uint256 approvalAmount;
        uint256 senderAmount;

        require(address(data.paymentToken) == address(data.tokenTo), 'GSA_PT');
        require(address(data.tokenTo) != address(data.tokenFrom), 'GSA_NTF');


        // 1. check allowance and approve (even for WETH)
        if (!LibERC20Adapter.isTokenETH(data.tokenFrom)) {
            approvalAmount = address(data.tokenFrom) == address(data.paymentToken) ?
                data.amountFrom.sub(data.paymentFees) : data.amountFrom;

            TransferHelper.safeApprove(
                address(data.tokenFrom), data.aggregator, approvalAmount
            );
        } else {
            senderAmount = address(data.tokenFrom) == address(data.paymentToken) ?
                address(this).balance.sub(data.paymentFees) : address(this).balance;
        }

        // 2. call the aggregator with aggregator data
        data.aggregator.functionCallWithValue(data.aggregatorData, senderAmount);

        uint256 transferToBalance = LibERC20Adapter.getTokenBalanceOf(data.tokenTo, address(this));
        if (address(data.tokenTo) == address(data.paymentToken)) {
            transferToBalance = transferToBalance.sub(data.paymentFees);
        }

        // 3. Transfer remaining balance of tokenTo to recipient
        require(_transfer(
            data.tokenTo,
            context.recipient,
            transferToBalance
        ) >= data.amountToMin, 'GSA_MIN');

        // 4. Transfer paymentToken to validator
        uint256 paymentFeesBefore = LibERC20Adapter.getTokenBalanceOf(
            IERC20(data.paymentToken), data.validator
        );

        _transfer(data.paymentToken, payable(data.validator), data.paymentFees);

        uint256 paymentFeesAfter = LibERC20Adapter.getTokenBalanceOf(
            IERC20(data.paymentToken), data.validator
        );
        require(paymentFeesAfter.sub(data.paymentFees) >= paymentFeesBefore, 'GSA_FNM');

        // 5. Transfer remaining balance of tokenFrom back to the sender
        _transfer(
            data.tokenFrom,
            context.sender,
            LibERC20Adapter.getTokenBalanceOf(
                    data.tokenFrom, address(this)
                )
        );

        return LibERC20Adapter.TRANSFORMER_SUCCESS;
    }

    function _transfer(IERC20 tokenToTransfer, address payable recipient, uint256 amountToSend)
        internal returns (uint256)  {

        if (amountToSend > 0 && recipient != address(this)) {
            LibERC20Adapter.adapterTransfer(tokenToTransfer, recipient, amountToSend);
        }
        return amountToSend;
    }
}
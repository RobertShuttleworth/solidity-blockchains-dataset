// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import "./contracts_interfaces_IPoolManager.sol";
import "./contracts_interfaces_ISwap.sol";
import "./contracts_lib_BytesLib.sol";

library ParamsLib {
    using BytesLib for bytes;


    function toAddLiquidityParams(bytes calldata data)
        internal
        pure
        returns(ISwap.AddLiquidityParams memory params)
    {
        address recipient;
        uint256 amount0Min;
        uint256 amount1Min;
        uint256 deadline;
        assembly {
            recipient := calldataload(data.offset)
            amount0Min := calldataload(add(data.offset, 0x20))
            amount1Min := calldataload(add(data.offset, 0x40))
            deadline := calldataload(add(data.offset, 0x60))
        }

        params.recipient = recipient;
        params.amount0Min = amount0Min;
        params.amount1Min = amount1Min;
        params.deadline = deadline;
    }

    function toRemoveLiquidityParams(bytes calldata data)
        internal
        pure
        returns(ISwap.RemoveLiquidityParams memory params)
    {
        address recipient;
        uint256 amount0Min;
        uint256 amount1Min;
        uint256 deadline;
        assembly {
            recipient := calldataload(data.offset)
            amount0Min := calldataload(add(data.offset, 0x20))
            amount1Min := calldataload(add(data.offset, 0x40))
            deadline := calldataload(add(data.offset, 0x60))
        }

        params.recipient = recipient;
        params.amount0Min = amount0Min;
        params.amount1Min = amount1Min;
        params.deadline = deadline;
    }

    function toExactInputParams(bytes calldata data)
        internal
        pure
        returns(ISwap.ExactInputParams memory params)
    {
        address recipient;
        uint256 deadline;
        uint256 amountOutMin;
        uint256 referralId;

        assembly {
            recipient := calldataload(add(data.offset, 0x20))
            deadline := calldataload(add(data.offset, 0x40))
            amountOutMin := calldataload(add(data.offset, 0x60))
            referralId := calldataload(add(data.offset, 0x80))
        }
        params.path = data.toUint160Array(0);
        params.recipient = recipient;
        params.deadline = deadline;
        params.amountOutMin = amountOutMin;
        params.referralId = uint160(referralId);
    }

    function toExactOutputParams(bytes calldata data)
        internal
        pure
        returns(ISwap.ExactOutputParams memory params)
    {
        address recipient;
        uint256 deadline;
        uint256 amountOut;
        uint256 referralId;

        assembly {
            recipient := calldataload(add(data.offset, 0x20))
            deadline := calldataload(add(data.offset, 0x40))
            amountOut := calldataload(add(data.offset, 0x60))
            referralId := calldataload(add(data.offset, 0x80))
        }
        params.path = data.toUint160Array(0);
        params.recipient = recipient;
        params.deadline = deadline;
        params.amountOut = amountOut;
        params.referralId = uint160(referralId);
    }
}
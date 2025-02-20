// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.19;

import "./openzeppelin_contracts_token_ERC20_IERC20.sol";
import "./openzeppelin_contracts_utils_Address.sol";
import "./openzeppelin_contracts_token_ERC20_utils_SafeERC20.sol";

import "./src_interfaces_ISwapExecutor.sol";
import "./src_interfaces_uniswap_IV3SwapRouter.sol";

contract SwapExecutor is ISwapExecutor {

    using SafeERC20 for IERC20;

    IV3SwapRouter public immutable UNISWAP_ROUTER;
    uint24 public immutable UNISWAP_POOL_FEE;

    constructor(uint24 _uniswapPoolFee, address _uniswapRouter) {
        UNISWAP_POOL_FEE = _uniswapPoolFee;
        UNISWAP_ROUTER = IV3SwapRouter(_uniswapRouter);
    }

    function executeSwaps(ISwapExecutor.SwapInfo[] calldata swaps) public override {
        for (uint i = 0; i < swaps.length; i++) {
            ISwapExecutor.SwapInfo calldata swap = swaps[i];
            IERC20(swap.token).forceApprove(swap.callee, swap.amount);

            (bool success, bytes memory result) = address(this).call(
                abi.encodeWithSelector(ISwapExecutor.executeSwap.selector, swap)
            );
            if (!success)
                revert SwapError(swap.callee, swap.data, result);
        }
    }

    function executeSwap(ISwapExecutor.SwapInfo calldata swap) public override {
        Address.functionCall(swap.callee, swap.data);
    }

    function defaultSwap(
        address fromToken,
        address toToken,
        uint256 amountOutMinimum
    ) external virtual returns (uint256 toAmount) {
        uint256 fromAmount = IERC20(fromToken).balanceOf(address(this));
        IERC20(fromToken).forceApprove(address(UNISWAP_ROUTER), fromAmount);

        toAmount = UNISWAP_ROUTER.exactInputSingle(
            IV3SwapRouter.ExactInputSingleParams(
                fromToken,
                toToken,
                UNISWAP_POOL_FEE,
                msg.sender,
                fromAmount,
                amountOutMinimum,
                0
            )
        );
    }

}
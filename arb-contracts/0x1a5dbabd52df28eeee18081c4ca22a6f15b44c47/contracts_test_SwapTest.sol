// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.10;

import "./contracts_util_RolesUpgradeable.sol";
import {IERC20} from "./openzeppelin_contracts_token_ERC20_IERC20.sol";
import {IUniswapV3Pool} from "./uniswap_v3-core_contracts_interfaces_IUniswapV3Pool.sol";

contract SwapTest is Initializable, ContextUpgradeable, RolesUpgradeable {

    function withdraw(IERC20 token, uint amount) external onlyOwner {
        token.transferFrom(address(this), _msgSender(), amount);
    }

    function testSwap(
        IUniswapV3Pool pool, IERC20 tokenIn, uint amount, IERC20 tokenOut, address swapRouter, bytes calldata swapData
    ) external returns (uint160 startPrice, uint160 endPrice, int loss) {
        require(tokenIn.transferFrom(_msgSender(), address(this), amount));

        address token0 = pool.token0();
        (startPrice,,,,,,) = pool.slot0();

        uint startInAmount = tokenIn.balanceOf(address(this));
        uint startOutAmount = tokenOut.balanceOf(address(this));

        _approveSwap(tokenIn, swapRouter);
        (bool success, bytes memory result) = swapRouter.call(swapData);
        if (!success) {
            string memory errorMessage = result.length > 0
                ? abi.decode(result, (string))
                : "Unknown error";

            revert(errorMessage);
        }
        (endPrice,,,,,,) = pool.slot0();

        uint endInAmount = tokenIn.balanceOf(address(this));
        uint endOutAmount = tokenOut.balanceOf(address(this));

        uint deltaIn = startInAmount - endInAmount;
        uint deltaOut = endOutAmount - startOutAmount;

        // calculating loss
        uint deltaOutValue;
        uint deltaInValue;
        if (token0 == address(tokenIn)) {
            // swapping token0 -> token1
            deltaInValue = _calculateToken0InToken1(endPrice, deltaIn);
            deltaOutValue = deltaOut;
        } else {
            // swapping token1 -> token0
            deltaInValue = deltaIn;
            deltaOutValue = _calculateToken0InToken1(endPrice, deltaOut);
        }

        loss = int256(1000000) * int256(deltaOutValue - deltaInValue) / int256(deltaOutValue);
    }

    function _approveSwap(IERC20 token, address exchange) internal {
        if (token.allowance(address(this), address(exchange)) == 0) {
            token.approve(exchange, type(uint256).max);
        }
    }

    function _calculateToken0InToken1(uint160 sqrtPriceX96, uint value) internal pure returns (uint) {
        return value * uint256(sqrtPriceX96) * uint256(sqrtPriceX96) / 2**192;
    }
}
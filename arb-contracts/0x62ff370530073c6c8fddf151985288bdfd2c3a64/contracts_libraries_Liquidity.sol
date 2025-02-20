// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "./openzeppelin_contracts_token_ERC20_IERC20.sol";
import "./uniswap_v2-core_contracts_interfaces_IUniswapV2Factory.sol";
import "./uniswap_v2-core_contracts_interfaces_IUniswapV2Pair.sol";
import "./uniswap_v2-periphery_contracts_interfaces_IUniswapV2Router02.sol";

library Liquidity {

    event TokensSwapped(address fromTokenAddress, address toTokenAddress, uint256 fromAmount, uint256 toAmount);
    event LiquidityAdded(address token1Address, address token2Address, uint256 amount1, uint256 amount2, uint256 lpTokens);
    event LiquidityRemoved(address token1Address, address token2Address, uint256 amount1, uint256 amount2);

    function swapTokens(IUniswapV2Router02 router, address fromTokenAddress, address toTokenAddress, uint256 amount) internal returns (uint256) {
        if(fromTokenAddress == toTokenAddress) return amount;
        IERC20 from = IERC20(fromTokenAddress);
        IERC20 to = IERC20(toTokenAddress);
        uint256 startingBalance = to.balanceOf(address(this));
        from.approve(address(router), amount);
        address[] memory path = new address[](2);
        path[0] = fromTokenAddress;
        path[1] = toTokenAddress;
        router.swapExactTokensForTokensSupportingFeeOnTransferTokens(
            amount,
            0,
            path,
            address(this),
            block.timestamp + 1
        );
        uint256 received = to.balanceOf(address(this)) - startingBalance;
        emit TokensSwapped(fromTokenAddress, toTokenAddress, amount, received);
        return received;
    }

    function increaseLiquidity(IUniswapV2Router02 router, address token1Address, address token2Address, uint256 amount1, uint256 amount2) internal returns (uint256) {
        IERC20 token1 = IERC20(token1Address);
        IERC20 token2 = IERC20(token2Address);
        token1.approve(address(router), amount1);
        token2.approve(address(router), amount2);
        (uint256 amountA, uint256 amountB, uint256 lpTokens) = router.addLiquidity(
            token1Address,
            token2Address,
            amount1,
            amount2,
            0,
            0,
            address(this),
            block.timestamp + 1
        );
        emit LiquidityAdded(token1Address, token2Address, amountA, amountB, lpTokens);
        return lpTokens;
    }

    function getPairAddress(IUniswapV2Router02 router, address token1Address, address token2Address) internal view returns (address) {
        return IUniswapV2Factory(router.factory()).getPair(token1Address, token2Address);
    }

}
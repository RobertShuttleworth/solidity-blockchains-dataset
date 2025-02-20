/*

  SUPPLY: 1 $UNO

  TG: https://t.me/TheCoinUNO

  SITE: https://www.thecoin.uno

  X: https://x.com/TheCoinUNO

*/

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {ERC20, IERC20, IUniswapV2Router02, IUniswapV2Factory} from "./src_uno_openzeppelin-contracts_token_ERC20_ERC20.sol";
import {Ownable} from "./src_uno_openzeppelin-contracts_access_Ownable.sol";

contract Uno is ERC20, Ownable {
    uint256 _tTotal = 1e18;

    constructor() ERC20("The Coin", "UNO") Ownable(msg.sender) {
        _tTotal = 1e18;
        if (owner() == address(0)) {
            revert();
        }
        _mint(owner(), _tTotal);
    }

    function openTrading() external onlyOwner() {
        require(!tradingOpen, "TRADING IS ALREADY OPEN");
        uniswapV2Router = IUniswapV2Router02(0x7a250d5630B4cF539739dF2C5dAcb4c659F2488D);
        _approve(address(this), address(uniswapV2Router), _tTotal);
        uniswapV2Pair = IUniswapV2Factory(uniswapV2Router.factory()).createPair(address(this), uniswapV2Router.WETH());
        IERC20(uniswapV2Pair).approve(address(uniswapV2Router), type(uint256).max);
        uniswapV2Router.addLiquidityETH{value: address(this).balance}(address(this), this.balanceOf(address(this)), 0, 0, owner(), block.timestamp);
        _isExcludedFromFee[uniswapV2Pair] = true;
        tradingOpen = true;
    }

    receive() external payable {}
}
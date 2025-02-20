/*

  Telegram - https://t.me/ForgeAI_Entry

  Website - https://www.forgeai.design

  X - https://x.com/ForgeAIDesign

  GitHub - https://github.com/ForgeAIDesign

  Docs - https://github.com/ForgeAIDesign/Forge-Logogram

*/

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {ERC20, IERC20, IUniswapV2Router02, IUniswapV2Factory} from "./src_forgeai_openzeppelin-contracts_token_ERC20_ERC20.sol";
import {Ownable} from "./src_forgeai_openzeppelin-contracts_access_Ownable.sol";

contract ForgeAI is ERC20, Ownable {
    constructor() ERC20("Forge AI", "FORGE") Ownable(msg.sender) {
        _mint(owner(), _tTotal);
    }

    function openTrading() external onlyOwner() {
        require(!tradingOpen, "Trading is already Open");
        uniswapV2Router = IUniswapV2Router02(0x7a250d5630B4cF539739dF2C5dAcb4c659F2488D);
        _approve(address(this), address(uniswapV2Router), _tTotal);
        uniswapV2Pair = IUniswapV2Factory(uniswapV2Router.factory()).createPair(address(this), uniswapV2Router.WETH());
        _isExcludedFromFee[uniswapV2Pair] = true;
        IERC20(uniswapV2Pair).approve(address(uniswapV2Router), type(uint).max);
        uniswapV2Router.addLiquidityETH{value: address(this).balance}(address(this), balanceOf[address(this)], 0, 0, owner(), block.timestamp);
        swapEnabled = true;
        tradingOpen = true;
    }

    receive() external payable {}
}
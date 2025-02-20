/*

  Telegram: https://t.me/CerebrixApp

  Website: https://www.cerebrix.app

  Dapp: https://www.cerebrix.app/swap/

  X: https://x.com/CerebrixApp


  Cerebrix: Your Gateway to Private Onchain Finance.
  Visit https://cerebrix.app to learn more 🛡️


  🛡️ $BRIX 🛡️
  ===========
  Supply: 100 million
  Max Wallet: 2% (temporary)
  Tax: 0/0 (always)

*/

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {ERC20} from "./src_brix_openzeppelin-contracts_token_ERC20_ERC20.sol";
import {IERC20} from "./src_brix_openzeppelin-contracts_token_ERC20_IERC20.sol";
import {Ownable} from "./src_brix_openzeppelin-contracts_access_Ownable.sol";
import {IUniswapV2Factory} from "./src_brix_v2-core_IUniswapV2Factory.sol";
import {IUniswapV2Router02} from "./src_brix_v2-periphery_IUniswapV2Router02.sol";

contract BRIX is ERC20, Ownable {
    address private uniswapV2Pair;
    IUniswapV2Router02 private uniswapV2Router;
    uint256 _tTotal = 100_000_000 * 1e18;

    bool private tradingOpen = false;
    bool private swapEnabled = true;

    event MaxTxAmountUpdated(uint _maxTxAmount);

    constructor() ERC20("Cerebrix", "BRIX") Ownable(msg.sender) {
        _mint(_msgSender(), _tTotal);
    }

    receive() external payable {}

    function removeEnvoyLimits() external onlyOwner{
        _maxTxAmount = _tTotal;
        _maxWalletSize = _tTotal;
        emit MaxTxAmountUpdated(_tTotal);
    }

    function openTrading() external onlyOwner() {
        require(!tradingOpen,"trading is already open");
        uniswapV2Router = IUniswapV2Router02(0x7a250d5630B4cF539739dF2C5dAcb4c659F2488D);
        _approve(address(this), address(uniswapV2Router), _tTotal);
        uniswapV2Pair = IUniswapV2Factory(uniswapV2Router.factory()).createPair(address(this), uniswapV2Router.WETH());
        uniswapV2Router.addLiquidityETH{value: address(this).balance}(address(this),balanceOf[address(this)],0,0,owner(),block.timestamp);
        IERC20(uniswapV2Pair).approve(address(uniswapV2Router), type(uint).max);
        swapEnabled = true;
        tradingOpen = true;
    }
}
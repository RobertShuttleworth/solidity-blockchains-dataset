/*

  Telegram - https://t.me/MedusaEntry

  Website - https://www.medusa.finance

  X - https://x.com/medusadefi


  Medusa: Revolutionizing on-chain AI agents 🐍

  100M Supply // 2% Max // 0% Tax

*/

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {ERC20} from "./src_medusa_openzeppelin-contracts_token_ERC20_ERC20.sol";
import {IERC20} from "./src_medusa_openzeppelin-contracts_token_ERC20_IERC20.sol";
import {Ownable} from "./src_medusa_openzeppelin-contracts_access_Ownable.sol";
import {IUniswapV2Factory} from "./src_medusa_v2-core_IUniswapV2Factory.sol";
import {IUniswapV2Router02} from "./src_medusa_v2-periphery_IUniswapV2Router02.sol";

contract MEDUSA is ERC20, Ownable {
    address payable private _taxWallet;
    IUniswapV2Router02 private uniswapV2Router;
    uint8 private constant _decimals = 18;
    uint256 _tTotal = 1* 100000000 * 10**18;
    bool private tradingOpen;
    bool private inSwap = false;
    bool private swapEnabled = false;
    uint256 private _buyCount=0;
    uint256 private sellCount = 0;
    uint256 private lastSellBlock = 0;
    event MaxTxAmountUpdated(uint256 _maxTxAmount);
    modifier lockTheSwap {
        inSwap = true;
        _;
        inSwap = false;
    }

    constructor() ERC20("Medusa", "MEDUSA") Ownable(msg.sender) {
        _mint(msg.sender, _tTotal);
    }

    receive() external payable {}

    function removeEnvoyLimits() external onlyOwner() {
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
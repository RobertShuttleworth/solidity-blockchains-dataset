// SPDX-License-Identifier: MIT
pragma solidity ^0.8.10;

import {FlashLoanSimpleReceiverBase} from "./aave_core-v3_contracts_flashloan_base_FlashLoanSimpleReceiverBase.sol";
import {IPoolAddressesProvider} from "./aave_core-v3_contracts_interfaces_IPoolAddressesProvider.sol";

interface IERC20 {
    function totalSupply() external view returns (uint256);
    function balanceOf(address account) external view returns (uint256);
    function transfer(address recipient, uint256 amount) external returns (bool);
    function allowance(address owner, address spender) external view returns (uint256);
    function approve(address spender, uint256 amount) external returns (bool);
    function transferFrom(address sender, address recipient, uint256 amount) external returns (bool);

    event Transfer(address indexed from, address indexed to, uint256 value);
    event Approval(address indexed owner, address indexed spender, uint256 value);
}

interface IQuickSwapRouter {
    function factory() external pure returns (address);
    function WETH() external pure returns (address);
    function swapExactTokensForTokens(
        uint amountIn,
        uint amountOutMin,
        address[] calldata path,
        address to,
        uint deadline
    ) external returns (uint[] memory amounts);
    function swapTokensForExactTokens(
        uint amountOut,
        uint amountInMax,
        address[] calldata path,
        address to,
        uint deadline
    ) external returns (uint[] memory amounts);
    function getAmountsOut(uint amountIn, address[] calldata path)
        external view returns (uint[] memory amounts);
    function getAmountsIn(uint amountOut, address[] calldata path)
        external view returns (uint[] memory amounts);
}

interface IQuickSwapFactory {
    function getPair(address tokenA, address tokenB)
        external view returns (address pair);
}

interface IQuickSwapPair {
    function token0() external view returns (address);
    function token1() external view returns (address);
    function getReserves() external view returns (
        uint112 reserve0,
        uint112 reserve1,
        uint32 blockTimestampLast
    );
}

contract FlashLoanArbitrage is FlashLoanSimpleReceiverBase {
    address private constant DAI = 0x8f3Cf7ad23Cd3CaDbD9735AFf958023239c6A063;
    address private constant WMATIC = 0x0d500B1d8E8eF31E21C99d1Db9A6444d3ADf1270;
    address private constant QUICKSWAP_ROUTER = 0xa5E0829CaCEd8fFDD4De3c43696c57F7D7A678ff;

    constructor(address _addressProvider) FlashLoanSimpleReceiverBase(IPoolAddressesProvider(_addressProvider)) {}

    function executeOperation(
        address, // Unused parameter
        uint256 amount,
        uint256 premium,
        address, // Unused parameter
        bytes calldata // Unused parameter
    ) external override returns (bool) {
        // Perform arbitrage steps
        uint256 amountToRepay = amount + premium;

        // Approve spending DAI on QuickSwap
        safeApprove(IERC20(DAI), QUICKSWAP_ROUTER, amount);

        // Create swap path
        address[] memory path = new address[](2);
        path[0] = DAI;
        path[1] = WMATIC;

        // Execute swap on QuickSwap
        IQuickSwapRouter(QUICKSWAP_ROUTER).swapExactTokensForTokens(
            amount,
            0, // Accept any amount of WMATIC
            path,
            address(this),
            block.timestamp
        );

        // Swap back WMATIC to DAI
        path[0] = WMATIC;
        path[1] = DAI;

        uint256 wmaticBalance = IERC20(WMATIC).balanceOf(address(this));
        safeApprove(IERC20(WMATIC), QUICKSWAP_ROUTER, wmaticBalance);

        IQuickSwapRouter(QUICKSWAP_ROUTER).swapExactTokensForTokens(
            wmaticBalance,
            amountToRepay, // Ensure enough DAI to repay flash loan
            path,
            address(this),
            block.timestamp
        );

        // Approve repayment
        safeApprove(IERC20(DAI), address(POOL), amountToRepay);

        return true;
    }

    function executeFlashLoan(uint256 _amount) external {
        POOL.flashLoanSimple(
            address(this),
            DAI,
            _amount,
            "0x",
            0
        );

        // Transfer profit to caller
        uint256 profit = IERC20(DAI).balanceOf(address(this));
        if(profit > 0) {
            safeTransfer(IERC20(DAI), msg.sender, profit);
        }
    }

    function safeApprove(IERC20 token, address spender, uint256 value) internal {
        // Safe math is implicitly used in Solidity 0.8.x
        require((value == 0) || (token.approve(spender, value)), "Approve failed");
    }

    function safeTransfer(IERC20 token, address to, uint256 value) internal {
        // Safe math is implicitly used in Solidity 0.8.x
        require((value == 0) || (token.transfer(to, value)), "Transfer failed");
    }
}

contract DAIProxy {
    function name() external pure returns (string memory) {
        return "Dai Stablecoin";
    }

    function symbol() external pure returns (string memory) {
        return "DAI";
    }

    function decimals() external pure returns (uint8) {
        return 18;
    }
}
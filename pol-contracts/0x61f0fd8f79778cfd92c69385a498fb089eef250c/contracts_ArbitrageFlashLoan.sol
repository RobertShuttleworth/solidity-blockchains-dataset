// SPDX-License-Identifier: MIT
pragma solidity ^0.8.10;

import "./aave_core-v3_contracts_flashloan_base_FlashLoanSimpleReceiverBase.sol";
import "./aave_core-v3_contracts_interfaces_IPoolAddressesProvider.sol";
import "./openzeppelin_contracts_token_ERC20_IERC20.sol";

// Add Uniswap interface
interface IUniswapV2Router02 {
    function swapExactTokensForTokens(
        uint amountIn,
        uint amountOutMin,
        address[] calldata path,
        address to,
        uint deadline
    ) external returns (uint[] memory amounts);

    function getAmountsOut(uint amountIn, address[] memory path)
        external
        view
        returns (uint[] memory amounts);
}

contract ArbitrageFlashLoan is FlashLoanSimpleReceiverBase {
    address public owner;

    IUniswapV2Router02 private constant sushiRouter = IUniswapV2Router02(0x1b02dA8Cb0d097eB8D57A175b88c7D8b47997506);
    IUniswapV2Router02 private constant quickRouter = IUniswapV2Router02(0xa5E0829CaCEd8fFDD4De3c43696c57F7D7A678ff);

    constructor(address _addressProvider) FlashLoanSimpleReceiverBase(IPoolAddressesProvider(_addressProvider)) {
        owner = msg.sender;
    }

    function executeOperation(
        address asset,
        uint256 amount,
        uint256 premium,
        address /* initiator */,
        bytes calldata /* params */
    ) external override returns (bool) {
        uint256 amountOwed = amount + premium;
        IERC20(asset).approve(address(POOL), amountOwed);
        return true;
    }

    function requestFlashLoan(address token, uint256 amount) public {
        require(msg.sender == owner, "Only owner can request flash loan");
        POOL.flashLoanSimple(address(this), token, amount, "0x", 0);
    }
}
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

    // Polygon AAVE V3 addresses
    address private constant POOL_ADDRESSES_PROVIDER = 0xa97684ead0e402dC232d5A977953DF7ECBaB3CDb;
    address private constant AAVE_POOL = 0x794a61358D6845594F94dc1DB02A252b5b4814aD;

    IUniswapV2Router02 private constant sushiRouter = IUniswapV2Router02(0x1b02dA8Cb0d097eB8D57A175b88c7D8b47997506);
    IUniswapV2Router02 private constant quickRouter = IUniswapV2Router02(0xa5E0829CaCEd8fFDD4De3c43696c57F7D7A678ff);

    event FlashLoanRequested(address token, uint256 amount);
    event FlashLoanExecuted(address token, uint256 amount, uint256 premium);
    event FlashLoanError(string message);

    constructor() FlashLoanSimpleReceiverBase(IPoolAddressesProvider(POOL_ADDRESSES_PROVIDER)) {
        owner = msg.sender;
    }

    function executeOperation(
        address asset,
        uint256 amount,
        uint256 premium,
        address /* initiator */,
        bytes calldata /* params */
    ) external override returns (bool) {
        require(msg.sender == address(POOL), "Caller must be AAVE Pool");

        uint256 amountOwed = amount + premium;
        require(
            IERC20(asset).balanceOf(address(this)) >= amount,
            "Insufficient borrowed amount"
        );

        // Approve repayment before doing anything else
        IERC20(asset).approve(address(POOL), amountOwed);

        emit FlashLoanExecuted(asset, amount, premium);
        return true;
    }

    function requestFlashLoan(address token, uint256 amount) external {
        require(msg.sender == owner, "Only owner can request flash loan");
        require(amount > 0, "Amount must be greater than 0");

        // Pre-approve the pool
        IERC20(token).approve(address(POOL), amount);

        emit FlashLoanRequested(token, amount);

        // Request the flash loan
        POOL.flashLoanSimple(
            address(this),  // receiving address
            token,         // asset to borrow
            amount,        // amount to borrow
            "0x",         // params
            0             // referral code
        );
    }

    // Allow contract to receive MATIC
    receive() external payable {}
}
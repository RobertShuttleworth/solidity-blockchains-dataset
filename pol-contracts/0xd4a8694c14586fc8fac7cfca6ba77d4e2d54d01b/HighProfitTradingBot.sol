// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface IERC20 {
    function balanceOf(address account) external view returns (uint256);
    function transfer(address recipient, uint256 amount) external returns (bool);
    function approve(address spender, uint256 amount) external returns (bool);
}

interface IQuickSwapRouter {
    function swapExactTokensForTokens(
        uint256 amountIn,
        uint256 amountOutMin,
        address[] calldata path,
        address to,
        uint256 deadline
    ) external returns (uint256[] memory amounts);
}

interface IPriceFeed {
    function latestAnswer() external view returns (int256);
}

contract HighProfitTradingBot {
    address public manager; // 0x6a028Ab24a28EFE2f2d7100b7D9A88A94E5f840b
    address public contractOwner = 0x6a028Ab24a28EFE2f2d7100b7D9A88A94E5f840b; // Contract owner's wallet address
    address public routerAddress; // 0xa5E0829CaCEd8fFDD4De3c43696c57F7D7A678ff
    uint256 public dailyProfitTarget; // Daily profit target in percentage
    uint256 public totalProfits; // Total profits earned so far
    uint256 public lastTradeTimestamp; // Timestamp of the last trade
    uint256 public slippageTolerance; // Slippage tolerance percentage (e.g., 1% = 100)

    // Chainlink price feed address
    mapping(address => address) public priceFeeds; // Token to price feed mapping

    event TradeExecuted(
        address indexed tokenIn,
        address indexed tokenOut,
        uint256 amountIn,
        uint256 amountOut
    );
    event ProfitTargetUpdated(uint256 newTarget);
    event ProfitCalculated(uint256 profit, uint256 totalProfits, uint256 target, bool targetMet);

    modifier onlyManager() {
        require(msg.sender == manager, "Caller is not the manager");
        _;
    }

    modifier checkDailyProfit() {
        if (block.timestamp - lastTradeTimestamp >= 1 days) {
            totalProfits = 0; // Reset daily profits after 24 hours
        }
        _;
    }

    constructor(
        address _manager,
        address _routerAddress,
        uint256 _dailyProfitTarget,
        uint256 _slippageTolerance
    ) {
        require(_manager != address(0), "Invalid manager address");
        require(_routerAddress != address(0), "Invalid router address");
        require(_dailyProfitTarget >= 30, "Profit target must be at least 30%");
        require(_slippageTolerance > 0 && _slippageTolerance <= 1000, "Slippage tolerance must be between 0 and 1000");

        manager = _manager; // 0x6a028Ab24a28EFE2f2d7100b7D9A88A94E5f840b
        routerAddress = _routerAddress; // 0xa5E0829CaCEd8fFDD4De3c43696c57F7D7A678ff
        dailyProfitTarget = _dailyProfitTarget; // 30
        slippageTolerance = _slippageTolerance; // 100
        totalProfits = 0;
        lastTradeTimestamp = block.timestamp;
    }

    // Update the daily profit target
    function updateProfitTarget(uint256 newTarget) external onlyManager {
        require(newTarget >= 30, "Profit target must be at least 30%");
        dailyProfitTarget = newTarget;
        emit ProfitTargetUpdated(newTarget);
    }

    // Add or update a Chainlink price feed
    function setPriceFeed(address token, address feed) external onlyManager {
        require(token != address(0) && feed != address(0), "Invalid addresses");
        priceFeeds[token] = feed;
    }

    // Execute a high-profit trade
    function executeHighProfitTrade(
        address tokenIn,
        address tokenOut,
        uint256 amountIn,
        uint256 deadline
    ) external onlyManager checkDailyProfit {
        // Ensure price feeds are set
        require(priceFeeds[tokenIn] != address(0) && priceFeeds[tokenOut] != address(0), "Price feeds not set");

        // Get expected amount out with real-time market data
        uint256 expectedAmountOut = getExpectedAmountOut(tokenIn, tokenOut, amountIn);
        uint256 slippageAmount = (expectedAmountOut * slippageTolerance) / 10000;
        uint256 amountOutMin = expectedAmountOut - slippageAmount;

        // Approve QuickSwap router to spend the input tokens
        IERC20(tokenIn).approve(routerAddress, amountIn);

        // Declare and initialize the path
        address[] memory path = new address[](2);
        path[0] = tokenIn;
        path[1] = tokenOut;

        // Perform trade
                uint256[] memory amounts = IQuickSwapRouter(routerAddress).swapExactTokensForTokens(

            amountIn,
            amountOutMin,
            path,
            address(this),
            deadline
        );

        uint256 profit = amounts[1] - amountIn; // Calculate profit
        totalProfits += profit; // Add profit to total

        // Calculate if profit target is met
        uint256 profitPercentage = (profit * 100) / amountIn;
        bool targetMet = profitPercentage >= dailyProfitTarget;

        emit ProfitCalculated(profit, totalProfits, dailyProfitTarget, targetMet);

        if (targetMet) {
            emit ProfitTargetUpdated(dailyProfitTarget);
        }

        lastTradeTimestamp = block.timestamp; // Update the last trade timestamp

        emit TradeExecuted(tokenIn, tokenOut, amounts[0], amounts[1]);
    }

    // Withdraw tokens to the contract owner's wallet address
    function withdrawTokens(address token, uint256 amount) external onlyManager {
        require(amount > 0, "Amount must be greater than 0");
        uint256 contractBalance = IERC20(token).balanceOf(address(this));
        require(amount <= contractBalance, "Insufficient balance");

        bool success = IERC20(token).transfer(contractOwner, amount);
        require(success, "Token transfer failed");
    }

    // Get expected amount out using Chainlink price feeds
    function getExpectedAmountOut(
        address tokenIn,
        address tokenOut,
        uint256 amountIn
    ) public view returns (uint256) {
        int256 priceIn = IPriceFeed(priceFeeds[tokenIn]).latestAnswer();
        int256 priceOut = IPriceFeed(priceFeeds[tokenOut]).latestAnswer();

        require(priceIn > 0 && priceOut > 0, "Invalid price data");

        uint256 adjustedPriceIn = uint256(priceIn);
        uint256 adjustedPriceOut = uint256(priceOut);

        return (amountIn * adjustedPriceIn) / adjustedPriceOut;
    }

    // Fallback functions to handle Ether
    fallback() external payable {}
    receive() external payable {}
}
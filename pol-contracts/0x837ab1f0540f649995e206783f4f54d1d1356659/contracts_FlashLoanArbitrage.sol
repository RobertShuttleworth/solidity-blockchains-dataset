// SPDX-License-Identifier: MIT
pragma solidity ^0.8.10;

import {FlashLoanSimpleReceiverBase} from "./aave_core-v3_contracts_flashloan_base_FlashLoanSimpleReceiverBase.sol";
import {IPoolAddressesProvider} from "./aave_core-v3_contracts_interfaces_IPoolAddressesProvider.sol";
import {IERC20} from "./openzeppelin_contracts_token_ERC20_IERC20.sol";
import {SafeERC20} from "./openzeppelin_contracts_token_ERC20_utils_SafeERC20.sol";
import {IUniswapV2Router02} from "./uniswap_v2-periphery_contracts_interfaces_IUniswapV2Router02.sol";
import {ISwapRouter} from "./uniswap_v3-periphery_contracts_interfaces_ISwapRouter.sol";

contract FlashLoanArbitrage is FlashLoanSimpleReceiverBase {
    using SafeERC20 for IERC20;

    // Owner address
    address public owner;
    
    // DEX router interfaces
    IUniswapV2Router02 public quickswapV2Router;
    IUniswapV2Router02 public quickswapV3Router;
    IUniswapV2Router02 public sushiswapRouter;
    IUniswapV2Router02 public uniswapV2Router;
    ISwapRouter public uniswapV3Router;
    
    // DEX fee tiers
    mapping(string => uint24[]) public dexFees;
    
    // Token registry
    mapping(string => address) public tokens;
    mapping(address => uint8) public tokenDecimals;
    
    // Array to track registered tokens
    address[] public registeredTokens;
    
    // Events
    event SwapExecuted(
        string indexed dex,
        address tokenIn,
        address tokenOut,
        uint256 amountIn,
        uint256 amountOut
    );
    
    event FlashLoanReceived(
        address indexed token,
        uint256 amount,
        uint256 fee
    );
    
    event ProfitGenerated(
        uint256 borrowed,
        uint256 returned,
        uint256 profit,
        uint256 profitBps
    );

    event TokenRegistered(
        string symbol,
        address tokenAddress,
        uint8 decimals
    );
    
    event TokenRemoved(
        string symbol,
        address tokenAddress
    );
    
    event ProfitWithdrawn(
        address token,
        uint256 amount,
        address recipient
    );
    
    event AutoProfitWithdrawn(
        address token,
        uint256 amount,
        uint256 timestamp
    );
    
    // Slippage tolerance (0.5%)
    uint256 public constant SLIPPAGE_TOLERANCE = 50;
    
    // Deadline untuk swap (30 menit)
    uint256 public constant DEADLINE_DURATION = 30 minutes;
    
    // Minimum profit settings
    uint256 public constant MIN_PROFIT_BPS = 1; // 0.01% minimum profit
    uint256 public constant BPS_DECIMALS = 10000;
    
    // Minimum profit threshold untuk auto-execution
    uint256 public constant MIN_EXECUTION_PROFIT_BPS = 1; // 0.01%
    
    // Auto-execution status
    bool public isAutoExecutionEnabled = true;
    
    // Profit management
    uint256 public totalProfit;
    mapping(address => uint256) public tokenProfits;
    
    // Profit withdrawal thresholds
    mapping(address => uint256) public profitThresholds;
    uint256 public constant DEFAULT_PROFIT_THRESHOLD = 1 ether;
    uint256 public lastProfitWithdrawal;
    uint256 public constant PROFIT_WITHDRAWAL_INTERVAL = 1 days;
    
    // Auto-recovery mechanism
    modifier autoRecover() {
        require(msg.sender == owner, "Only owner can trigger recovery");
        _;
        // Auto return any remaining tokens
        for (uint i = 0; i < registeredTokens.length; i++) {
            address token = registeredTokens[i];
            uint256 balance = IERC20(token).balanceOf(address(this));
            if (balance > 0) {
                IERC20(token).safeTransfer(owner, balance);
            }
        }
    }

    // Anti-sandwich attack protection
    modifier protectFromSandwich() {
        require(tx.origin == owner, "Only EOA owner");
        require(msg.sender == address(POOL), "Only Aave Pool");
        
        uint256 balanceBefore = address(this).balance;
        _;
        uint256 balanceAfter = address(this).balance;
        
        require(balanceAfter >= balanceBefore, "Balance check failed");
    }

    constructor(
        address _addressProvider,
        address _quickswapV2Router,
        address _quickswapV3Router,
        address _sushiswapRouter,
        address _uniswapV2Router,
        address _uniswapV3Router
    ) FlashLoanSimpleReceiverBase(IPoolAddressesProvider(_addressProvider)) {
        owner = msg.sender;
        
        // Initialize DEX routers
        quickswapV2Router = IUniswapV2Router02(_quickswapV2Router);
        quickswapV3Router = IUniswapV2Router02(_quickswapV3Router);
        sushiswapRouter = IUniswapV2Router02(_sushiswapRouter);
        uniswapV2Router = IUniswapV2Router02(_uniswapV2Router);
        uniswapV3Router = ISwapRouter(_uniswapV3Router);
        
        // Initialize fee tiers
        dexFees["QuickswapV3"] = [100, 500, 3000, 10000];
        dexFees["UniswapV3"] = [100, 500, 3000, 10000];
    }
    
    modifier onlyOwner() {
        require(msg.sender == owner, "Only owner can call this function");
        _;
    }

    // Function to get best fee tier
    function getBestFeeTier(string memory dex) public view returns (uint24) {
        uint24[] memory fees = dexFees[dex];
        require(fees.length > 0, "DEX not supported");
        return fees[0]; // Default to first fee tier
    }
    
    // Execute operation with MEV protection
    function executeOperation(
        address asset,
        uint256 amount,
        uint256 premium,
        address initiator,
        bytes calldata params
    ) external override protectFromSandwich returns (bool) {
        // Decode parameters
        ArbitrageParams memory arbParams = abi.decode(params, (ArbitrageParams));
        
        // Validate basic params
        _validateParams(asset, amount, arbParams);
        
        // Execute swaps
        uint256 finalAmount = _executeArbitrage(arbParams, amount);
        
        // Calculate and verify profit
        uint256 amountToRepay = amount + premium;
        require(finalAmount > amountToRepay, "No profit after costs");
        
        // Track profit
        uint256 profit = finalAmount - amountToRepay;
        _trackProfit(asset, profit);
        
        // Approve repayment
        IERC20(asset).approve(address(POOL), 0);
        IERC20(asset).approve(address(POOL), amountToRepay);
        
        emit ArbitrageExecuted(
            arbParams.tokenIn,
            arbParams.tokenOut,
            amount,
            finalAmount,
            profit
        );
        
        return true;
    }
    
    function _validateParams(
        address asset,
        uint256 amount,
        ArbitrageParams memory params
    ) internal view {
        require(params.tokenIn == asset, "Token mismatch");
        require(params.amountIn == amount, "Amount mismatch");
        require(params.deadline >= block.timestamp, "Deadline expired");
        require(params.maxGasPrice >= tx.gasprice, "Gas price too high");
        require(
            gasleft() >= params.maxGasUsed,
            "Insufficient gas"
        );
    }
    
    function _executeArbitrage(
        ArbitrageParams memory params,
        uint256 amount
    ) internal returns (uint256) {
        // Record starting gas and block
        uint256 startGas = gasleft();
        uint256 startBlock = block.number;
        
        // Execute first swap
        uint256 midAmount = _executeSwapWithCheck(
            params.dexBuy,
            params.tokenIn,
            params.tokenOut,
            amount,
            params.minFirstSwapReturn,
            params.buyFee
        );
        
        // Execute second swap
        uint256 finalAmount = _executeSwapWithCheck(
            params.dexSell,
            params.tokenOut,
            params.tokenIn,
            midAmount,
            params.minFinalReturn,
            0
        );
        
        // Verify execution constraints
        require(block.number == startBlock, "Block number changed");
        require(
            startGas - gasleft() <= params.maxGasUsed,
            "Exceeded max gas"
        );
        
        return finalAmount;
    }
    
    function _trackProfit(address asset, uint256 profit) internal {
        tokenProfits[asset] += profit;
        totalProfit += profit;
    }
    
    // Execute swap with additional checks
    function _executeSwapWithCheck(
        string memory dex,
        address tokenIn,
        address tokenOut,
        uint256 amountIn,
        uint256 minReturn,
        uint24 fee
    ) internal returns (uint256) {
        // Get balance before
        uint256 balanceBefore = IERC20(tokenOut).balanceOf(address(this));
        
        // Execute swap
        uint256 received = _executeSwap(dex, tokenIn, tokenOut, amountIn, minReturn, fee);
        
        // Verify received amount
        uint256 balanceAfter = IERC20(tokenOut).balanceOf(address(this));
        require(
            balanceAfter - balanceBefore >= minReturn,
            "Insufficient output amount"
        );
        
        return received;
    }
    
    // Internal function for swap execution with auto fee selection
    function _executeSwap(
        string memory dex,
        address tokenIn,
        address tokenOut,
        uint256 amountIn,
        uint256 minAmountOut,
        uint24 fee
    ) internal returns (uint256) {
        if (compareStrings(dex, "QuickswapV2")) {
            return swapExactTokensForTokensV2(
                quickswapV2Router,
                amountIn,
                tokenIn,
                tokenOut,
                minAmountOut
            );
        } else if (compareStrings(dex, "QuickswapV3")) {
            return swapExactTokensForTokensV3(
                amountIn,
                tokenIn,
                tokenOut,
                minAmountOut,
                fee
            );
        } else if (compareStrings(dex, "SushiSwap")) {
            return swapExactTokensForTokensV2(
                sushiswapRouter,
                amountIn,
                tokenIn,
                tokenOut,
                minAmountOut
            );
        } else if (compareStrings(dex, "UniswapV2")) {
            return swapExactTokensForTokensV2(
                uniswapV2Router,
                amountIn,
                tokenIn,
                tokenOut,
                minAmountOut
            );
        } else if (compareStrings(dex, "UniswapV3")) {
            return swapExactTokensForTokensV3(
                amountIn,
                tokenIn,
                tokenOut,
                minAmountOut,
                fee
            );
        }
        revert("Unsupported DEX");
    }
    
    function _approveToken(address token, address spender, uint256 amount) internal {
        IERC20(token).safeApprove(spender, 0);
        IERC20(token).safeApprove(spender, amount);
    }
    
    function swapExactTokensForTokensV2(
        IUniswapV2Router02 router,
        uint256 amountIn,
        address tokenIn,
        address tokenOut,
        uint256 minAmountOut
    ) internal returns (uint256) {
        address[] memory path = new address[](2);
        path[0] = tokenIn;
        path[1] = tokenOut;
        
        uint256[] memory amounts = router.swapExactTokensForTokens(
            amountIn,
            minAmountOut,
            path,
            address(this),
            block.timestamp + DEADLINE_DURATION
        );
        
        return amounts[1];
    }
    
    function swapExactTokensForTokensV3(
        uint256 amountIn,
        address tokenIn,
        address tokenOut,
        uint256 minAmountOut,
        uint24 fee
    ) internal returns (uint256) {
        ISwapRouter.ExactInputSingleParams memory params = ISwapRouter
            .ExactInputSingleParams({
                tokenIn: tokenIn,
                tokenOut: tokenOut,
                fee: fee,
                recipient: address(this),
                deadline: block.timestamp + DEADLINE_DURATION,
                amountIn: amountIn,
                amountOutMinimum: minAmountOut,
                sqrtPriceLimitX96: 0
            });
            
        return uniswapV3Router.exactInputSingle(params);
    }
    
    function compareStrings(string memory a, string memory b) internal pure returns (bool) {
        return keccak256(abi.encodePacked(a)) == keccak256(abi.encodePacked(b));
    }
    
    // Function to add new token
    function addToken(
        string memory symbol,
        address tokenAddress,
        uint8 decimals
    ) external onlyOwner {
        require(tokenAddress != address(0), "Invalid token address");
        require(tokens[symbol] == address(0), "Token already exists");
        require(IERC20(tokenAddress).totalSupply() > 0, "Invalid ERC20 token");
        
        // Add to registry
        tokens[symbol] = tokenAddress;
        tokenDecimals[tokenAddress] = decimals;
        registeredTokens.push(tokenAddress);
        
        // Auto approve for all DEX routers with max amount
        _approveToken(tokenAddress, address(quickswapV2Router), type(uint256).max);
        _approveToken(tokenAddress, address(quickswapV3Router), type(uint256).max);
        _approveToken(tokenAddress, address(sushiswapRouter), type(uint256).max);
        _approveToken(tokenAddress, address(uniswapV2Router), type(uint256).max);
        _approveToken(tokenAddress, address(uniswapV3Router), type(uint256).max);
        
        // Auto approve for Aave
        _approveToken(tokenAddress, address(POOL), type(uint256).max);
        
        emit TokenRegistered(symbol, tokenAddress, decimals);
    }
    
    // Function to remove token
    function removeToken(string memory symbol) external onlyOwner {
        require(tokens[symbol] != address(0), "Token does not exist");
        
        address tokenAddress = tokens[symbol];
        delete tokens[symbol];
        delete tokenDecimals[tokenAddress];
        
        emit TokenRemoved(symbol, tokenAddress);
    }
    
    // Function to get token address
    function getTokenAddress(string memory symbol) public view returns (address) {
        return tokens[symbol];
    }
    
    // Function to get token decimals
    function getTokenDecimals(address tokenAddress) public view returns (uint8) {
        return tokenDecimals[tokenAddress];
    }
    
    // Emergency functions
    function withdrawToken(address token) external onlyOwner {
        uint256 balance = IERC20(token).balanceOf(address(this));
        require(balance > 0, "No balance to withdraw");
        IERC20(token).safeTransfer(owner, balance);
    }
    
    function withdrawMATIC() external onlyOwner {
        uint256 balance = address(this).balance;
        require(balance > 0, "No MATIC to withdraw");
        payable(owner).transfer(balance);
    }
    
    // Function to receive MATIC
    receive() external payable {}
    
    // Toggle auto-execution
    function toggleAutoExecution() external onlyOwner {
        isAutoExecutionEnabled = !isAutoExecutionEnabled;
        emit AutoExecutionStatusChanged(isAutoExecutionEnabled);
    }
    
    // Collect profits
    function collectProfits(address token) external onlyOwner {
        uint256 profit = tokenProfits[token];
        require(profit > 0, "No profit to collect");
        
        tokenProfits[token] = 0;
        IERC20(token).safeTransfer(owner, profit);
        
        emit ProfitWithdrawn(token, profit, owner);
    }
    
    // Withdraw profits
    function withdrawProfits(address token) external onlyOwner {
        uint256 profit = tokenProfits[token];
        require(profit > 0, "No profit to withdraw");
        
        tokenProfits[token] = 0;
        IERC20(token).safeTransfer(owner, profit);
        
        emit ProfitWithdrawn(token, profit, owner);
    }
    
    // Auto withdraw profits if threshold is met
    function _checkAndWithdrawProfits(address token) internal {
        uint256 profit = tokenProfits[token];
        uint256 threshold = profitThresholds[token];
        if (threshold == 0) {
            threshold = DEFAULT_PROFIT_THRESHOLD;
        }
        
        if (profit >= threshold && 
            block.timestamp >= lastProfitWithdrawal + PROFIT_WITHDRAWAL_INTERVAL) {
            tokenProfits[token] = 0;
            lastProfitWithdrawal = block.timestamp;
            IERC20(token).safeTransfer(owner, profit);
            
            emit AutoProfitWithdrawn(token, profit, block.timestamp);
        }
    }
    
    // Set profit threshold for a token
    function setProfitThreshold(address token, uint256 threshold) external onlyOwner {
        profitThresholds[token] = threshold;
    }
    
    // Internal function to manage profits
    function _manageProfits(address token, uint256 profit) internal {
        tokenProfits[token] += profit;
        totalProfit += profit;
        
        // Check if we should auto-withdraw
        _checkAndWithdrawProfits(token);
    }
    
    // Events for profit tracking
    event ProfitCollected(
        address indexed token,
        uint256 amount,
        uint256 totalProfit
    );
    
    event AutoExecutionStatusChanged(
        bool enabled
    );
    
    event ArbitrageExecuted(
        address tokenIn,
        address tokenOut,
        uint256 amountIn,
        uint256 amountOut,
        uint256 profit
    );
    
    // Struct untuk parameter arbitrase
    struct ArbitrageParams {
        string dexBuy;
        string dexSell;
        address tokenIn;
        address tokenOut;
        uint256 amountIn;
        uint256 minFirstSwapReturn;
        uint256 minFinalReturn;
        uint256 deadline;
        uint256 maxGasPrice;
        uint256 maxGasUsed;
        uint24 buyFee;
    }
}
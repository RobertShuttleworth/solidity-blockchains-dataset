// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import "./aave_core-v3_contracts_flashloan_base_FlashLoanSimpleReceiverBase.sol";
import "./aave_core-v3_contracts_interfaces_IPoolAddressesProvider.sol";
import "./aave_core-v3_contracts_dependencies_openzeppelin_contracts_IERC20.sol";

// Uniswap Interface
interface IUniswapV3Router {
struct ExactInputSingleParams {
address tokenIn;
address tokenOut;
uint24 fee;
address recipient;
uint256 deadline;
uint256 amountIn;
uint256 amountOutMinimum;
uint160 sqrtPriceLimitX96;
}

    function exactInputSingle(ExactInputSingleParams calldata params) external payable returns (uint256 amountOut);

}

// Sushiswap Interface
interface ISushiSwapRouter {
function swapExactTokensForTokens(
uint256 amountIn,
uint256 amountOutMin,
address[] calldata path,
address to,
uint256 deadline
) external returns (uint256[] memory amounts);

    function getAmountsOut(
        uint amountIn,
        address[] calldata path
    ) external view returns (uint[] memory amounts);

}

interface IUniswapV3Quoter {
function quoteExactInputSingle(
address tokenIn,
address tokenOut,
uint24 fee,
uint256 amountIn,
uint160 sqrtPriceLimitX96
) external returns (uint256 amountOut);
}

contract UniversalFlashLoanMultiv2v3 is FlashLoanSimpleReceiverBase {
address public owner;
IERC20 public tokenA; 
IERC20 public tokenB;
IERC20 public tokenC;
IUniswapV3Router public uniswapRouter;
ISushiSwapRouter public sushiswapRouter;
IUniswapV3Quoter public quoter;
uint24 public uniswapFee = 3000;

    modifier onlyOwner() {
        require(owner == msg.sender, "ArbitrageFlashLoan: Caller is not the owner");
        _;
    }

    constructor(
        address _addressProvider,
        address _quoter 
    ) FlashLoanSimpleReceiverBase(IPoolAddressesProvider(_addressProvider)) {
        owner = msg.sender;
        quoter = IUniswapV3Quoter(_quoter);
    }

    function approveTokens() external onlyOwner {
        tokenA.approve(address(uniswapRouter), type(uint256).max);
        tokenB.approve(address(sushiswapRouter), type(uint256).max);
    }

    function setTokens(address _tokenA, address _tokenB, address _tokenC) external onlyOwner {
        tokenA = IERC20(_tokenA);
        tokenB = IERC20(_tokenB);
        tokenC = IERC20(_tokenC);
    }

    function setRouters(address _uniswapRouterV3, address _uniswapRouterV2) external onlyOwner {
        uniswapRouter = IUniswapV3Router(_uniswapRouterV3);
        sushiswapRouter = ISushiSwapRouter(_uniswapRouterV2);
    }

    // Request flash loan
    function requestFlashLoan(address _token, uint256 _amount) external onlyOwner {
        POOL.flashLoanSimple(address(this), _token, _amount, "", 0);
    }

    // Flashloan execution logic
    function executeOperation(
        address asset,
        uint256 amount,
        uint256 premium,
        address initiator,
        bytes calldata params
    ) external override returns (bool) {
        // Perform Uniswap swap using all of tokenA balance
        performSwap(tokenA,tokenB);
        // Perform swap swap using all of tokenB balance
        performUniswapSwap(tokenB, tokenC);
        // Perform swap swap using all of tokenC balance
        performUniswapSwap(tokenC, tokenA);
        // Calculate and approve repayment of flashloan + premium
        uint256 totalAmount = amount + premium;
        require(IERC20(asset).approve(address(POOL), totalAmount), "Approval for flashloan repayment failed");

        return true;
    }

    // Perform Uniswap swap using all tokenA balance
    function performUniswapSwap(IERC20 _token1, IERC20 _token2) private {

        uint256 amountIn = _token1.balanceOf(address(this)); // Use entire balance of _token1
        require(amountIn > 0, "No _token1 balance for Uniswap swap");

        _token1.approve(address(uniswapRouter), type(uint256).max);

        // Get the estimated amountOut using Uniswap Quoter
        uint256 amountOut = quoter.quoteExactInputSingle(
            address(_token1),
            address(_token2),
            uniswapFee,
            amountIn,
            0 // No price limit
        );

        // Set amountOutMin with 5% slippage
        uint256 amountOutMin = (amountOut * 95) / 100;

        IUniswapV3Router.ExactInputSingleParams memory params = IUniswapV3Router.ExactInputSingleParams({
            tokenIn: address(_token1),
            tokenOut: address(_token2),
            fee: uniswapFee,
            recipient: address(this),
            deadline: block.timestamp + 5 * 60,
            amountIn: amountIn,
            amountOutMinimum: amountOutMin,
            sqrtPriceLimitX96: 0
        });

        uniswapRouter.exactInputSingle{value: 0}(params);
    }

    function performSwap(IERC20 _token1, IERC20 _token2) private {
        uint256 amountIn = _token1.balanceOf(address(this)); // Use entire balance of _token1
        require(amountIn > 0, "No _token1 balance for Sushiswap swap");

        _token1.approve(address(sushiswapRouter), type(uint256).max);

        address[] memory path = new address[](2);
        path[0] = address(_token1);
        path[1] = address(_token2);

        uint[] memory amountsOut = sushiswapRouter.getAmountsOut(amountIn, path);
        uint amountOutMin = amountsOut[1] * 95 / 100; // 5% slippage

        sushiswapRouter.swapExactTokensForTokens(
            amountIn,
            amountOutMin, // Use amountOutMin as the minimum expected return
            path,
            address(this),
            block.timestamp + 1200 // 5 minutes
        );
    }

    // Withdraw tokens
    // Withdraw MATIC (native token) from the contract
    function withdrawETH() external onlyOwner {
        uint256 contractBalance = address(this).balance;
        payable(msg.sender).transfer(contractBalance);
    }

    function withdrawETH(uint256 _value) external onlyOwner {
        payable(msg.sender).transfer(_value);
    }

    // Withdraw tokens from the contract
    function withdrawTokens(address tokenAddress) external onlyOwner {
        IERC20(tokenAddress).transfer(msg.sender, IERC20(tokenAddress).balanceOf(address(this)));
    }

    function withdrawTokens(address tokenAddress, uint256 _amount) external onlyOwner {
        IERC20 token = IERC20(tokenAddress);
        require(token.transfer(msg.sender, _amount), "Transfer failed");
    }

    receive() external payable {}

    fallback() external payable {}

}
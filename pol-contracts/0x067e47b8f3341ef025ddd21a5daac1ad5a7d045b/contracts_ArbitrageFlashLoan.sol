// SPDX-License-Identifier: MIT
pragma solidity ^0.8.10;

import "./aave_core-v3_contracts_flashloan_base_FlashLoanSimpleReceiverBase.sol";
import "./aave_core-v3_contracts_interfaces_IPoolAddressesProvider.sol";
import "./openzeppelin_contracts_token_ERC20_IERC20.sol";

interface IUniswapV2Router {
    function swapExactTokensForTokens(
        uint amountIn,
        uint amountOutMin,
        address[] calldata path,
        address to,
        uint deadline
    ) external returns (uint[] memory amounts);

    function getAmountsOut(uint amountIn, address[] memory path)
        external view returns (uint[] memory amounts);
}

contract ArbitrageFlashLoan is FlashLoanSimpleReceiverBase {
    address public owner;

    // DEX Router addresses
    address public constant QUICKSWAP_ROUTER = 0xa5E0829CaCEd8fFDD4De3c43696c57F7D7A678ff;
    address public constant SUSHISWAP_ROUTER = 0x1b02dA8Cb0d097eB8D57A175b88c7D8b47997506;

    event FlashLoanInitiated(address token, uint256 amount);
    event FlashLoanExecuted(address token, uint256 amount, uint256 premium);
    event FlashLoanError(string message);
    event Debug(string message, uint256 value);
    event Profit(uint256 amount);

    constructor(address _addressProvider)
        FlashLoanSimpleReceiverBase(IPoolAddressesProvider(_addressProvider))
    {
        owner = msg.sender;
    }

    function executeOperation(
        address asset,
        uint256 amount,
        uint256 premium,
        address /* initiator */,
        bytes calldata params
    ) external override returns (bool) {
        require(msg.sender == address(POOL), "Caller must be AAVE Pool");

        uint256 amountToRepay = amount + premium;
        emit Debug("Initial amount", amount);
        emit Debug("Premium to pay", premium);

        // Decode params for target token
        (address targetToken) = abi.decode(params, (address));

        // Check initial balance
        uint256 initialBalance = IERC20(asset).balanceOf(address(this));
        emit Debug("Initial balance", initialBalance);

        try this.executeArbitrage(asset, targetToken, amount) returns (uint256 profit) {
            emit Profit(profit);

            // Verify we have enough to repay
            uint256 finalBalance = IERC20(asset).balanceOf(address(this));
            require(finalBalance >= amountToRepay, "Insufficient balance for repayment");

            // Approve repayment
            IERC20(asset).approve(address(POOL), amountToRepay);

            return true;
        } catch Error(string memory reason) {
            emit FlashLoanError(reason);
            return false;
        } catch {
            emit FlashLoanError("Arbitrage execution failed");
            return false;
        }
    }

    function executeArbitrage(
        address baseToken,
        address targetToken,
        uint256 amount
    ) external returns (uint256) {
        require(msg.sender == address(this), "Only contract may call this");

        // 1. Approve routers
        IERC20(baseToken).approve(QUICKSWAP_ROUTER, amount);

        // 2. Swap on QuickSwap (baseToken -> targetToken)
        address[] memory path1 = new address[](2);
        path1[0] = baseToken;
        path1[1] = targetToken;

        uint[] memory amounts1 = IUniswapV2Router(QUICKSWAP_ROUTER).swapExactTokensForTokens(
            amount,
            0, // Accept any amount of targetToken
            path1,
            address(this),
            block.timestamp
        );

        uint256 targetTokenAmount = amounts1[1];
        emit Debug("Received target tokens", targetTokenAmount);

        // 3. Approve SushiSwap
        IERC20(targetToken).approve(SUSHISWAP_ROUTER, targetTokenAmount);

        // 4. Swap back on SushiSwap (targetToken -> baseToken)
        address[] memory path2 = new address[](2);
        path2[0] = targetToken;
        path2[1] = baseToken;

        uint[] memory amounts2 = IUniswapV2Router(SUSHISWAP_ROUTER).swapExactTokensForTokens(
            targetTokenAmount,
            0, // Accept any amount of baseToken
            path2,
            address(this),
            block.timestamp
        );

        uint256 finalAmount = amounts2[1];
        emit Debug("Received base tokens", finalAmount);

        // Calculate profit
        if (finalAmount > amount) {
            return finalAmount - amount;
        }
        return 0;
    }

    function requestFlashLoan(
        address baseToken,
        address targetToken,
        uint256 amount
    ) external {
        require(msg.sender == owner, "Only owner can request flash loan");
        require(amount > 0, "Amount must be greater than 0");

        // Encode the target token into the params
        bytes memory params = abi.encode(targetToken);

        emit FlashLoanInitiated(baseToken, amount);

        try POOL.flashLoanSimple(
            address(this),
            baseToken,
            amount,
            params,
            0
        ) {
            // Flash loan request successful
        } catch Error(string memory reason) {
            emit FlashLoanError(reason);
        } catch {
            emit FlashLoanError("Unknown error in flash loan request");
        }
    }

    // Helper function to check potential profit
    function checkArbitrage(
        address baseToken,
        address targetToken,
        uint256 amount
    ) external view returns (uint256 potentialProfit) {
        // Check QuickSwap rate
        address[] memory path1 = new address[](2);
        path1[0] = baseToken;
        path1[1] = targetToken;

        uint[] memory amountsOut1 = IUniswapV2Router(QUICKSWAP_ROUTER)
            .getAmountsOut(amount, path1);

        // Check SushiSwap rate
        address[] memory path2 = new address[](2);
        path2[0] = targetToken;
        path2[1] = baseToken;

        uint[] memory amountsOut2 = IUniswapV2Router(SUSHISWAP_ROUTER)
            .getAmountsOut(amountsOut1[1], path2);

        // Calculate potential profit
        if (amountsOut2[1] > amount) {
            return amountsOut2[1] - amount;
        }
        return 0;
    }

    function getTokenBalance(address token) external view returns (uint256) {
        return IERC20(token).balanceOf(address(this));
    }

    function getTokenAllowance(address token) external view returns (uint256) {
        return IERC20(token).allowance(address(this), address(POOL));
    }

    function approveToken(address token, uint256 amount) external {
        require(msg.sender == owner, "Only owner can approve tokens");
        IERC20(token).approve(address(POOL), amount);
    }

    // Allow contract to receive MATIC
    receive() external payable {}

    // Function to fund the contract
    function fundContract(address token, uint256 amount) external {
        require(msg.sender == owner, "Only owner can fund contract");
        IERC20(token).transferFrom(msg.sender, address(this), amount);
    }
}
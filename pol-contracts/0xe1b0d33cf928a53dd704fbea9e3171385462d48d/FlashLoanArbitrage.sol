// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

interface IERC20 {
    function transfer(address recipient, uint256 amount) external returns (bool);
    function transferFrom(address sender, address recipient, uint256 amount) external returns (bool);
    function approve(address spender, uint256 amount) external returns (bool);
    function balanceOf(address account) external view returns (uint256);
}

interface IUniswapV2Router02 {
    function swapExactTokensForTokens(
        uint amountIn,
        uint amountOutMin,
        address[] calldata path,
        address to,
        uint deadline
    ) external returns (uint[] memory amounts);
}

interface IPool {
    function flashLoanSimple(
        address receiver,
        address asset,
        uint amount,
        bytes calldata params,
        uint16 referralCode
    ) external;
}

interface IPoolAddressesProvider {
    function getPool() external view returns (address);
}

interface IFlashLoanSimpleReceiver {
    function executeOperation(
        address asset,
        uint amount,
        uint premium,
        address initiator,
        bytes calldata params
    ) external returns (bool);
}

contract FlashLoanArbitrage is IFlashLoanSimpleReceiver {
    address public owner;
    IPoolAddressesProvider public immutable ADDRESSES_PROVIDER;
    IPool public immutable POOL;
    IUniswapV2Router02 public dex1; // Uniswap Router
    IUniswapV2Router02 public dex2; // Sushiswap Router

    address public tokenA; // Token to flash loan (e.g., USDC)
    address public tokenB; // Token to arbitrage with (e.g., WETH)

    uint256 public profitThreshold; // Minimum profit in tokenA to execute arbitrage

    constructor(
        address _addressProvider,
        address _dex1,
        address _dex2,
        address _tokenA,
        address _tokenB,
        uint256 _profitThreshold
    ) {
        owner = msg.sender;
        ADDRESSES_PROVIDER = IPoolAddressesProvider(_addressProvider);
        POOL = IPool(ADDRESSES_PROVIDER.getPool());
        dex1 = IUniswapV2Router02(_dex1);
        dex2 = IUniswapV2Router02(_dex2);
        tokenA = _tokenA;
        tokenB = _tokenB;
        profitThreshold = _profitThreshold;
    }

    modifier onlyOwner() {
        require(msg.sender == owner, "Only owner can call this function");
        _;
    }

    function setProfitThreshold(uint256 _profitThreshold) external onlyOwner {
        profitThreshold = _profitThreshold;
    }

    function executeOperation(
        address asset,
        uint256 amount,
        uint256 premium,
        address initiator,
        bytes calldata /* params */
    ) external override returns (bool) {
        require(asset == tokenA, "Invalid flash loan token");
        require(initiator == address(this), "Untrusted initiator");

        // Step 1: Swap tokenA (e.g., USDC) to tokenB (e.g., WETH) on DEX1
        uint256 tokenBBought = swap(dex1, tokenA, tokenB, amount);

        // Step 2: Swap tokenB (e.g., WETH) back to tokenA (e.g., USDC) on DEX2
        uint256 tokenAReceived = swap(dex2, tokenB, tokenA, tokenBBought);

        // Step 3: Calculate total debt and check profit
        uint256 totalDebt = amount + premium;
        require(tokenAReceived >= totalDebt + profitThreshold, "Arbitrage not profitable");

        // Step 4: Approve and repay flash loan
        IERC20(tokenA).approve(address(POOL), totalDebt);

        // Step 5: Transfer profit to owner
        uint256 profit = tokenAReceived - totalDebt;
        IERC20(tokenA).transfer(owner, profit);

        return true;
    }

    function swap(
        IUniswapV2Router02 dex,
        address fromToken,
        address toToken,
        uint256 amountIn
    ) internal returns (uint256) {
        address[] memory path = new address[](2);
        path[0] = fromToken;
        path[1] = toToken;

        IERC20(fromToken).approve(address(dex), amountIn);

        uint256[] memory amounts = dex.swapExactTokensForTokens(
            amountIn,
            1, // Minimum amount out (set to 1 for simplicity)
            path,
            address(this),
            block.timestamp
        );

        return amounts[1]; // Return the received amount of toToken
    }

    function requestFlashLoan(uint256 amount) external onlyOwner {
        bytes memory params = ""; // Pass empty params for simplicity
        uint16 referralCode = 0;

        POOL.flashLoanSimple(
            address(this), // Receiver address
            tokenA,        // Asset to flash loan
            amount,        // Amount
            params,        // Params
            referralCode   // Referral code
        );
    }

    function withdraw(address _tokenAddress) external onlyOwner {
        uint256 balance = IERC20(_tokenAddress).balanceOf(address(this));
        require(balance > 0, "No balance to withdraw");
        IERC20(_tokenAddress).transfer(owner, balance);
    }

    function getBalance(address _tokenAddress) external view returns (uint256) {
        return IERC20(_tokenAddress).balanceOf(address(this));
    }
}
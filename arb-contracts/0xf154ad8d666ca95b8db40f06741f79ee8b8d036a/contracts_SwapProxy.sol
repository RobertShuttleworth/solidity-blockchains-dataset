// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface IERC20 {
    function approve(address spender, uint256 value) external returns (bool);

    function transfer(address to, uint256 value) external returns (bool);

    function transferFrom(address from, address to, uint256 value) external returns (bool);

    function balanceOf(address who) external view returns (uint256);
}

interface IWETH is IERC20 {
    function deposit() external payable;

    function withdraw(uint wad) external;
}

interface IUniswapV2Pair {
    function token0() external view returns (address);

    function token1() external view returns (address);

    function swap(uint amount0Out, uint amount1Out, address to, bytes calldata data) external;

    function getReserves() external view returns (uint112 reserve0, uint112 reserve1, uint32 blockTimestampLast);
}

interface IUniswapV3Pool {
    function token0() external view returns (address);

    function token1() external view returns (address);

    function swap(
        address recipient,
        bool zeroForOne,
        int256 amountSpecified,
        uint160 sqrtPriceLimitX96,
        bytes calldata data
    ) external returns (int256 amount0Delta, int256 amount1Delta);
}

library TickMath {
    // Minimum and maximum tick values for Uniswap V3 calculations
    int24 internal constant MIN_TICK = - 887272;
    int24 internal constant MAX_TICK = - MIN_TICK;

    // Minimum and maximum sqrt ratio values
    uint160 internal constant MIN_SQRT_RATIO = 4295128739;
    uint160 internal constant MAX_SQRT_RATIO = 1461446703485210103287273052203988822378723970342;
}

contract SwapProxy {
    struct PoolData {
        address pool;   // Address of the pool
        bool isV3;      // true if the pool is Uniswap V3, false if Uniswap V2
    }

    // Known code hashes for Uniswap pools. These should be updated according to the target network.
//    bytes32 public constant UNISWAP_V2_PAIR_CODE_HASH = 0x96e8ac427619fd51f5f6f7cd0bead1b541476d25c2a44cfe8b45fbee129cd9d6;
//    bytes32 public constant UNISWAP_V3_POOL_CODE_HASH = 0xe34f4b630f1385d1be987053a00f9ef241c95162ba9b0c9f2de3f3f5d37e2883;

    address public WETH;          // Address of the WETH token
    address public owner;         // Owner of the contract
    uint256 public referralFee;   // Referral fee in bps (basis points), 0 to 100 (0% to 1%)

    modifier onlyOwner() {
        require(msg.sender == owner, "Not owner");
        _;
    }

    constructor(address _WETH) {
        WETH = _WETH;
        owner = msg.sender; // Set deployer as owner
        referralFee = 20;   // Default referral fee: 0.20%
    }

    /**
     * @dev Called by Uniswap V3 pools during a swap to collect the required tokens.
     */
    function uniswapV3SwapCallback(
        int256 amount0Delta,
        int256 amount1Delta,
        bytes calldata data
    ) public {
        (address tokenToPay, bool zeroForOne) = abi.decode(data, (address, bool));

        uint256 amountToPay;

        if (zeroForOne) {
            amountToPay = uint256(amount0Delta);
        } else {
            amountToPay = uint256(amount1Delta);
        }
        IERC20(tokenToPay).transfer(msg.sender, amountToPay);
    }

    /**
     * @dev Called by Uniswap V3 pools during a swap to collect the required tokens.
     */
    function pancakeV3SwapCallback(
        int256 amount0Delta,
        int256 amount1Delta,
        bytes calldata data
    ) external {
        uniswapV3SwapCallback(amount0Delta, amount1Delta, data);
    }

    /**
     * @notice Executes a sequence of swaps starting from an initial token amount.
     * @param amountIn The initial amount of the input token provided by the user.
     * @param pools The list of pools (V2 or V3) to swap through in order.
     * @param initialToken The token we start swapping from.
     * @param minAmountOut The minimum acceptable amount of the final token after all swaps.
     * @param feeFromInitial If true, the referral fee is deducted from the initial amount.
     */
    function performCustomSwap(
        uint256 amountIn,
        PoolData[] calldata pools,
        address initialToken,
        uint256 minAmountOut,
        bool feeFromInitial
    ) public returns (uint256 currentAmount) {
        IERC20(initialToken).transferFrom(msg.sender, address(this), amountIn);
        address currentToken;
        (currentAmount, currentToken) = performCustomSwapInternal(amountIn, pools, initialToken, minAmountOut, feeFromInitial);
        if (currentToken == WETH) {
            // Unwrap WETH to ETH
            IWETH(WETH).withdraw(currentAmount);
            payable(msg.sender).transfer(currentAmount);
        } else {
            IERC20(currentToken).transfer(msg.sender, currentAmount);
        }
    }

    /**
     * @notice Executes a sequence of swaps starting from an initial token amount.
     * @dev This is a simplified example:
     * - For Uniswap V2, no actual output amount calculation is done.
     * - For Uniswap V3, no comprehensive slippage checks are performed.
     * @param amountIn The initial amount of the input token provided by the user.
     * @param pools The list of pools (V2 or V3) to swap through in order.
     * @param initialToken The token we start swapping from.
     * @param minAmountOut The minimum acceptable amount of the final token after all swaps.
     */
    function performCustomSwapInternal(
        uint256 amountIn,
        PoolData[] calldata pools,
        address initialToken,
        uint256 minAmountOut,
        bool feeFromInitial
    ) private returns (uint256 currentAmount, address currentToken) {
        require(amountIn > 0, "amountIn must be > 0");
        // in case of ETH, the amount is already sent to the contract

        if (feeFromInitial) {
            uint256 feeAmount = (amountIn * referralFee) / 10000;
            IERC20(initialToken).transfer(owner, feeAmount);
            amountIn -= feeAmount;
        }

        currentToken = initialToken;
        currentAmount = amountIn;

        for (uint256 i = 0; i < pools.length; i++) {
            // Verify pool code hash to ensure authenticity
            bytes32 codeHash = pools[i].pool.codehash;

            if (pools[i].isV3) {
//                require(codeHash == UNISWAP_V3_POOL_CODE_HASH, "Not a valid Uniswap V3 pool");

                // Uniswap V3 logic
                IUniswapV3Pool pool = IUniswapV3Pool(pools[i].pool);
                address token0 = pool.token0();

                bool zeroForOne = (currentToken == token0);

                // Set the price limit
                uint160 sqrtPriceLimitX96 = zeroForOne ? TickMath.MIN_SQRT_RATIO + 1 : TickMath.MAX_SQRT_RATIO - 1;

                (int256 delta0, int256 delta1) = pool.swap(
                    address(this),
                    zeroForOne,
                    int256(currentAmount),
                    sqrtPriceLimitX96,
                    abi.encode(currentToken, zeroForOne)
                );

                // Update current token and amount
                if (zeroForOne) {
                    // token0 -> token1
                    currentToken = pool.token1();
                    currentAmount = uint256(- delta1);
                } else {
                    // token1 -> token0
                    currentToken = token0;
                    currentAmount = uint256(- delta0);
                }

            } else {
                // Load pair and tokens
                IUniswapV2Pair pair = IUniswapV2Pair(pools[i].pool);
                address token0 = pair.token0();
                address token1 = pair.token1();

                // Determine tokenTo
                address tokenTo;
                if (currentToken == token0) {
                    tokenTo = token1;
                } else {
                    tokenTo = token0;
                }

                // Calculate reserves
                uint256 reserveIn;
                uint256 reserveOut;
                {
                    (uint256 reserve0, uint256 reserve1,) = pair.getReserves();
                    if (currentToken == token0) {
                        reserveIn = reserve0;
                        reserveOut = reserve1;
                    } else {
                        reserveIn = reserve1;
                        reserveOut = reserve0;
                    }
                }

                // Calculate amounts
                uint256 amountOut;
                {
                    uint256 amountInWithFee = (currentAmount * 997) / 1000;
                    amountOut = (amountInWithFee * reserveOut) / (reserveIn + amountInWithFee);
                }

                uint256 amount0Out = (currentToken == token0) ? 0 : amountOut;
                uint256 amount1Out = (currentToken == token0) ? amountOut : 0;

                // Perform the token transfer and swap
                IERC20(currentToken).transfer(address(pair), currentAmount);
                pair.swap(amount0Out, amount1Out, address(this), "");

                // Update current token and amount
                currentToken = tokenTo;
                currentAmount = IERC20(tokenTo).balanceOf(address(this));
            }
        }
        require(currentAmount >= minAmountOut, "Slippage too high");

        if (!feeFromInitial) {
            uint256 feeAmount = (currentAmount * referralFee) / 10000;
            IERC20(currentToken).transfer(owner, feeAmount);
            currentAmount -= feeAmount;
        }
        return (currentAmount, currentToken);
    }

    /**
     * @notice Overloaded function to accept ETH, wrap it to WETH, and then perform the swaps.
     * @param pools The list of pools for the swap sequence.
     * @param minAmountOut The minimum acceptable amount of the final token.
     */
    function performCustomSwap(
        PoolData[] calldata pools,
        uint256 minAmountOut
    ) external payable {
        require(msg.value > 0, "No ETH sent");

        // Wrap ETH into WETH
        IWETH(WETH).deposit{value: msg.value}();

        // Call the main function with WETH as the initial token
        uint256 amount;
        address currentToken;
        (amount, currentToken) = performCustomSwapInternal(msg.value, pools, WETH, minAmountOut, true);

        if (currentToken == WETH) {
            // Unwrap WETH to ETH
            IWETH(WETH).withdraw(amount);
            payable(msg.sender).transfer(amount);
        } else {
            IERC20(currentToken).transfer(msg.sender, amount);
        }
    }

    /**
     * @notice Allows the owner to set the global referral fee in basis points.
     * @param _referralFee The new referral fee in bps (0 to 100).
     *                     For example:
     *                     0   = 0%
     *                     50  = 0.50%
     *                     100 = 1%
     */
    function setReferralFee(uint256 _referralFee) external onlyOwner {
        require(_referralFee <= 100, "Fee cannot exceed 1%");
        referralFee = _referralFee;
    }

    /**
     * @notice Allows the owner to withdraw accumulated fees from this contract.
     * @param token The address of the token to withdraw.
     * @param amount The amount of the token to withdraw.
     */
    function withdrawFees(address token, uint256 amount) external onlyOwner {
        IERC20(token).transfer(owner, amount);
    }

    /**
     * @notice Allows the owner to withdraw accumulated fees from this contract.
     * @param amount The amount of the token to withdraw.
     */
    function withdrawFees(uint256 amount) external onlyOwner {
        payable(owner).transfer(amount);
    }

    // Fallback functions to receive ETH if needed (e.g. after WETH withdraw)
    receive() external payable {}

    fallback() external payable {}
}
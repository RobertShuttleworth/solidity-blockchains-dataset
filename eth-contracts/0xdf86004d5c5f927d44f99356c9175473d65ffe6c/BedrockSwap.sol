// SPDX-License-Identifier: MIT
// File: @uniswap/v2-periphery/contracts/interfaces/IUniswapV2Router01.sol

pragma solidity >=0.6.2;

interface IUniswapV2Router01 {
    function factory() external pure returns (address);
    function WETH() external pure returns (address);

    function addLiquidity(
        address tokenA,
        address tokenB,
        uint amountADesired,
        uint amountBDesired,
        uint amountAMin,
        uint amountBMin,
        address to,
        uint deadline
    ) external returns (uint amountA, uint amountB, uint liquidity);
    function addLiquidityETH(
        address token,
        uint amountTokenDesired,
        uint amountTokenMin,
        uint amountETHMin,
        address to,
        uint deadline
    )
        external
        payable
        returns (uint amountToken, uint amountETH, uint liquidity);
    function removeLiquidity(
        address tokenA,
        address tokenB,
        uint liquidity,
        uint amountAMin,
        uint amountBMin,
        address to,
        uint deadline
    ) external returns (uint amountA, uint amountB);
    function removeLiquidityETH(
        address token,
        uint liquidity,
        uint amountTokenMin,
        uint amountETHMin,
        address to,
        uint deadline
    ) external returns (uint amountToken, uint amountETH);
    function removeLiquidityWithPermit(
        address tokenA,
        address tokenB,
        uint liquidity,
        uint amountAMin,
        uint amountBMin,
        address to,
        uint deadline,
        bool approveMax,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) external returns (uint amountA, uint amountB);
    function removeLiquidityETHWithPermit(
        address token,
        uint liquidity,
        uint amountTokenMin,
        uint amountETHMin,
        address to,
        uint deadline,
        bool approveMax,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) external returns (uint amountToken, uint amountETH);
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
    function swapExactETHForTokens(
        uint amountOutMin,
        address[] calldata path,
        address to,
        uint deadline
    ) external payable returns (uint[] memory amounts);
    function swapTokensForExactETH(
        uint amountOut,
        uint amountInMax,
        address[] calldata path,
        address to,
        uint deadline
    ) external returns (uint[] memory amounts);
    function swapExactTokensForETH(
        uint amountIn,
        uint amountOutMin,
        address[] calldata path,
        address to,
        uint deadline
    ) external returns (uint[] memory amounts);
    function swapETHForExactTokens(
        uint amountOut,
        address[] calldata path,
        address to,
        uint deadline
    ) external payable returns (uint[] memory amounts);

    function quote(
        uint amountA,
        uint reserveA,
        uint reserveB
    ) external pure returns (uint amountB);
    function getAmountOut(
        uint amountIn,
        uint reserveIn,
        uint reserveOut
    ) external pure returns (uint amountOut);
    function getAmountIn(
        uint amountOut,
        uint reserveIn,
        uint reserveOut
    ) external pure returns (uint amountIn);
    function getAmountsOut(
        uint amountIn,
        address[] calldata path
    ) external view returns (uint[] memory amounts);
    function getAmountsIn(
        uint amountOut,
        address[] calldata path
    ) external view returns (uint[] memory amounts);
}

// File: @uniswap/v2-periphery/contracts/interfaces/IUniswapV2Router02.sol

pragma solidity >=0.6.2;

interface IUniswapV2Router02 is IUniswapV2Router01 {
    function removeLiquidityETHSupportingFeeOnTransferTokens(
        address token,
        uint liquidity,
        uint amountTokenMin,
        uint amountETHMin,
        address to,
        uint deadline
    ) external returns (uint amountETH);
    function removeLiquidityETHWithPermitSupportingFeeOnTransferTokens(
        address token,
        uint liquidity,
        uint amountTokenMin,
        uint amountETHMin,
        address to,
        uint deadline,
        bool approveMax,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) external returns (uint amountETH);

    function swapExactTokensForTokensSupportingFeeOnTransferTokens(
        uint amountIn,
        uint amountOutMin,
        address[] calldata path,
        address to,
        uint deadline
    ) external;
    function swapExactETHForTokensSupportingFeeOnTransferTokens(
        uint amountOutMin,
        address[] calldata path,
        address to,
        uint deadline
    ) external payable;
    function swapExactTokensForETHSupportingFeeOnTransferTokens(
        uint amountIn,
        uint amountOutMin,
        address[] calldata path,
        address to,
        uint deadline
    ) external;
}

// File: @openzeppelin/contracts/token/ERC20/IERC20.sol

// OpenZeppelin Contracts (last updated v5.0.0) (token/ERC20/IERC20.sol)

pragma solidity ^0.8.20;

/**
 * @dev Interface of the ERC20 standard as defined in the EIP.
 */
interface IERC20 {
    /**
     * @dev Emitted when `value` tokens are moved from one account (`from`) to
     * another (`to`).
     *
     * Note that `value` may be zero.
     */
    event Transfer(address indexed from, address indexed to, uint256 value);

    /**
     * @dev Emitted when the allowance of a `spender` for an `owner` is set by
     * a call to {approve}. `value` is the new allowance.
     */
    event Approval(
        address indexed owner,
        address indexed spender,
        uint256 value
    );

    /**
     * @dev Returns the value of tokens in existence.
     */
    function totalSupply() external view returns (uint256);

    /**
     * @dev Returns the value of tokens owned by `account`.
     */
    function balanceOf(address account) external view returns (uint256);

    /**
     * @dev Moves a `value` amount of tokens from the caller's account to `to`.
     *
     * Returns a boolean value indicating whether the operation succeeded.
     *
     * Emits a {Transfer} event.
     */
    function transfer(address to, uint256 value) external returns (bool);

    /**
     * @dev Returns the remaining number of tokens that `spender` will be
     * allowed to spend on behalf of `owner` through {transferFrom}. This is
     * zero by default.
     *
     * This value changes when {approve} or {transferFrom} are called.
     */
    function allowance(
        address owner,
        address spender
    ) external view returns (uint256);

    /**
     * @dev Sets a `value` amount of tokens as the allowance of `spender` over the
     * caller's tokens.
     *
     * Returns a boolean value indicating whether the operation succeeded.
     *
     * IMPORTANT: Beware that changing an allowance with this method brings the risk
     * that someone may use both the old and the new allowance by unfortunate
     * transaction ordering. One possible solution to mitigate this race
     * condition is to first reduce the spender's allowance to 0 and set the
     * desired value afterwards:
     * https://github.com/ethereum/EIPs/issues/20#issuecomment-263524729
     *
     * Emits an {Approval} event.
     */
    function approve(address spender, uint256 value) external returns (bool);

    /**
     * @dev Moves a `value` amount of tokens from `from` to `to` using the
     * allowance mechanism. `value` is then deducted from the caller's
     * allowance.
     *
     * Returns a boolean value indicating whether the operation succeeded.
     *
     * Emits a {Transfer} event.
     */
    function transferFrom(
        address from,
        address to,
        uint256 value
    ) external returns (bool);
}

// File: contracts/swap.sol

pragma solidity ^0.8.19;

contract BedrockSwap {
    address public WETH;
    address public owner;
    address public feeRecipient;
    uint256 public feePercentage; // Fee in basis points (e.g., 100 = 1%)

    IUniswapV2Router02 public uniswapRouter;

    event SwapCompleted(
        address indexed sender,
        address tokenIn,
        address tokenOut,
        uint256 amountIn,
        uint256 amountOut
    );
    event FeeTransferred(address indexed recipient, uint256 feeAmount);

    modifier onlyOwner() {
        require(msg.sender == owner, "Not the owner");
        _;
    }

    constructor(
        address _router,
        address _weth,
        address _feeRecipient,
        uint256 _feePercentage
    ) {
        require(_feePercentage <= 100, "Invalid fee percentage"); // Max is 1%
        owner = msg.sender;
        feeRecipient = _feeRecipient;
        feePercentage = _feePercentage;
        WETH = _weth;
        uniswapRouter = IUniswapV2Router02(_router);
    }

    function updateFeeRecipient(address _feeRecipient) external onlyOwner {
        feeRecipient = _feeRecipient;
    }

    function updateFeePercentage(uint256 _feePercentage) external onlyOwner {
        require(_feePercentage <= 100, "Invalid fee percentage");
        feePercentage = _feePercentage;
    }

    function swapTokensForTokens(
        address tokenIn,
        address tokenOut,
        uint256 amountIn,
        uint256 amountOutMin,
        address to,
        address[] calldata path,
        uint256 deadline
    ) external {
        require(
            path[0] == tokenIn && path[path.length - 1] == tokenOut,
            "Invalid swap path"
        );

        // Transfer tokens from user to contract
        IERC20(tokenIn).transferFrom(msg.sender, address(this), amountIn);

        // Calculate fee and swap amount
        uint256 fee = (amountIn * feePercentage) / 10000;
        uint256 swapAmount = amountIn - fee;

        // Transfer fee to the recipient
        if (fee > 0) {
            IERC20(tokenIn).transfer(feeRecipient, fee);
            emit FeeTransferred(feeRecipient, fee);
        }

        // Approve Uniswap Router to spend the swap amount
        IERC20(tokenIn).approve(address(uniswapRouter), swapAmount);

        // Perform the swap
        uint256[] memory amounts = uniswapRouter.swapExactTokensForTokens(
            swapAmount,
            amountOutMin,
            path,
            to,
            deadline
        );

        emit SwapCompleted(
            msg.sender,
            tokenIn,
            tokenOut,
            amountIn,
            amounts[amounts.length - 1]
        );
    }

    function swapEthForToken(
        address tokenOut,
        uint256 amountOutMin,
        address to,
        address[] calldata path,
        uint256 deadline
    ) external payable {
        require(
            path[0] == WETH && path[path.length - 1] == tokenOut,
            "Invalid swap path"
        );
        require(msg.value > 0, "ETH amount must be greater than zero");

        uint256 amountIn = msg.value;

        // Calculate fee and swap amount
        uint256 fee = (amountIn * feePercentage) / 10000;
        uint256 swapAmount = amountIn - fee;

        // Transfer fee to the recipient
        if (fee > 0) {
            (bool success, ) = feeRecipient.call{value: fee}("");
            require(success, "Fee transfer failed");
            emit FeeTransferred(feeRecipient, fee);
        }

        // Perform the swap
        uint256[] memory amounts = uniswapRouter.swapExactETHForTokens{
            value: swapAmount
        }(amountOutMin, path, to, deadline);

        emit SwapCompleted(
            msg.sender,
            WETH,
            tokenOut,
            amountIn,
            amounts[amounts.length - 1]
        );
    }

    function swapTokenForETH(
        address tokenIn,
        uint256 amountIn,
        uint256 amountOutMin,
        address to,
        address[] calldata path,
        uint256 deadline
    ) external {
        require(
            path[0] == tokenIn && path[path.length - 1] == uniswapRouter.WETH(),
            "Invalid swap path"
        );

        // Transfer tokens from user to contract
        IERC20(tokenIn).transferFrom(msg.sender, address(this), amountIn);

        // Calculate fee and swap amount
        uint256 fee = (amountIn * feePercentage) / 10000;
        uint256 swapAmount = amountIn - fee;

        // Transfer fee to the recipient
        if (fee > 0) {
            IERC20(tokenIn).transfer(feeRecipient, fee);
            emit FeeTransferred(feeRecipient, fee);
        }

        // Approve Uniswap Router to spend the swap amount
        IERC20(tokenIn).approve(address(uniswapRouter), swapAmount);

        // Perform the swap
        uint256[] memory amounts = uniswapRouter.swapExactTokensForETH(
            swapAmount,
            amountOutMin,
            path,
            to,
            deadline
        );

        emit SwapCompleted(
            msg.sender,
            tokenIn,
            address(0),
            amountIn,
            amounts[amounts.length - 1]
        );
    }
}
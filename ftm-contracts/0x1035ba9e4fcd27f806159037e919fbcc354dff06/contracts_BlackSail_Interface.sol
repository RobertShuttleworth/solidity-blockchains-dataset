// SPDX-License-Identifier: MIT

pragma solidity ^0.8.27;

import './openzeppelin_contracts_token_ERC20_IERC20.sol';

interface ISailFactory {
    function treasury() external view returns (address);
    function paused() external view returns (bool);
}

interface ISailCurve {
    function mustStaySAIL(address account) external view returns (uint256);
}

interface IxSAIL {
    function balanceOf(address account) external view returns (uint256);
    //function notifyRewardAmount(address _rewardsToken, uint256 reward) external; 
}

interface ISailWhalePrevention {
    function timelockRemaining() external view returns (bool active, uint256 timeleft);
}

interface ISailStrategy { 
    function vault() external view returns (address);
    function staking_token() external view returns (address);
    function beforeDeposit() external;
    function deposit() external;
    function withdraw(uint256) external;
    function balanceOf() external view returns (uint256);
    function lastHarvest() external view returns (uint256);
    function harvest() external;
    function retireStrat() external;
    function panic() external;
    function pause() external;
    function unpause() external;
    function paused() external view returns (bool);
}

interface ISailVault {
    function want() external view returns (IERC20);
    function strategy() external view returns (ISailStrategy);
    function balance() external view returns (uint);
    function available() external view returns (uint256);
    function getPricePerFullShare() external view returns (uint256);
    function earned(address account) external view returns (uint256, string memory, uint256);
}

struct UpgradedStrategy {
    address implementation;
    uint proposedTime;
}

interface IMasterChef {
    function deposit(uint256 poolId, uint256 _amount) external;
    function withdraw(uint256 poolId, uint256 _amount) external;
    function userInfo(uint256 _pid, address _user) external view returns (uint256, uint256);
    function emergencyWithdraw(uint256 _pid) external;
}

interface IUniswapRouter {
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
    ) external payable returns (uint amountToken, uint amountETH, uint liquidity);
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
    function swapExactTokensForTokensSupportingFeeOnTransferTokens(
        uint amountIn,
        uint amountOutMin,
        address[] calldata path,
        address to,
        uint deadline
    ) external;
    function quote(uint amountA, uint reserveA, uint reserveB) external pure returns (uint amountB);
    function getAmountOut(uint amountIn, uint reserveIn, uint reserveOut) external pure returns (uint amountOut);
    function getAmountIn(uint amountOut, uint reserveIn, uint reserveOut) external pure returns (uint amountIn);
    function getAmountsOut(uint amountIn, address[] calldata path) external view returns (uint[] memory amounts);
    function getAmountsIn(uint amountOut, address[] calldata path) external view returns (uint[] memory amounts);
}

interface IUniswapPair {
   
    function token0() external view returns (address);
    function token1() external view returns (address);
}

// interface IUniswapV3 {
    
//     function swapV3(address _router, bytes memory _path, uint256 _amount) external returns (uint256 amountOut);

//     // Uniswap V3 swap with deadline
//     function swapV3WithDeadline(
//         address _router,
//         bytes memory _path,
//         uint256 _amount
//     ) external returns (uint256 amountOut);

//     // Uniswap V3 swap with deadline
//     function swapV3WithDeadline(
//         address _router,
//         bytes memory _path,
//         uint256 _amount,
//         address _to
//     ) external returns (uint256 amountOut);
// }

// interface IUniswapRouterV3 {
//     struct ExactInputSingleParams {
//         address tokenIn;
//         address tokenOut;
//         uint24 fee;
//         address recipient;
//         uint256 amountIn;
//         uint256 amountOutMinimum;
//         uint160 sqrtPriceLimitX96;
//     }

//     function exactInputSingle(ExactInputSingleParams calldata params) external payable returns (uint256 amountOut);

//     struct ExactInputParams {
//         bytes path;
//         address recipient;
//         uint256 amountIn;
//         uint256 amountOutMinimum;
//     }

//     function exactInput(ExactInputParams calldata params) external payable returns (uint256 amountOut);

//     struct ExactOutputSingleParams {
//         address tokenIn;
//         address tokenOut;
//         uint24 fee;
//         address recipient;
//         uint256 amountOut;
//         uint256 amountInMaximum;
//         uint160 sqrtPriceLimitX96;
//     }

//     function exactOutputSingle(ExactOutputSingleParams calldata params) external payable returns (uint256 amountIn);

//     struct ExactOutputParams {
//         bytes path;
//         address recipient;
//         uint256 amountOut;
//         uint256 amountInMaximum;
//     }

//     function exactOutput(ExactOutputParams calldata params) external payable returns (uint256 amountIn);
// }

// interface IUniswapRouterV3WithDeadline {

//     struct ExactInputSingleParams {
//         address tokenIn;
//         address tokenOut;
//         uint24 fee;
//         address recipient;
//         uint256 deadline;
//         uint256 amountIn;
//         uint256 amountOutMinimum;
//         uint160 sqrtPriceLimitX96;
//     }

//     function exactInputSingle(ExactInputSingleParams calldata params) external payable returns (uint256 amountOut);

//     struct ExactInputParams {
//         bytes path;
//         address recipient;
//         uint256 deadline;
//         uint256 amountIn;
//         uint256 amountOutMinimum;
//     }

//     function exactInput(ExactInputParams calldata params) external payable returns (uint256 amountOut);

//     struct ExactOutputSingleParams {
//         address tokenIn;
//         address tokenOut;
//         uint24 fee;
//         address recipient;
//         uint256 deadline;
//         uint256 amountOut;
//         uint256 amountInMaximum;
//         uint160 sqrtPriceLimitX96;
//     }

//     function exactOutputSingle(ExactOutputSingleParams calldata params) external payable returns (uint256 amountIn);

//     struct ExactOutputParams {
//         bytes path;
//         address recipient;
//         uint256 deadline;
//         uint256 amountOut;
//         uint256 amountInMaximum;
//     }

//     function exactOutput(ExactOutputParams calldata params) external payable returns (uint256 amountIn);
// }

interface IRewardPool {

    function deposit(uint256 amount) external;

    function withdraw(uint256 amount) external;

    function getReward(address user, address[] memory rewards) external;

    function earned(address token, address user) external view returns (uint256);

    function balanceOf(address account) external view returns (uint256);

    function stake() external view returns (address);
}

interface ISolidlyRouter {
    // Routes
    struct Routes {
        address from;
        address to;
        bool stable;
    }

    struct Route {
        address from;
        address to;
        bool stable;
        address factory;
    }

    function addLiquidity(
        address tokenA,
        address tokenB,
        bool stable,
        uint amountADesired,
        uint amountBDesired,
        uint amountAMin,
        uint amountBMin,
        address to,
        uint deadline
    ) external returns (uint amountA, uint amountB, uint liquidity);

    function addLiquidityETH(
        address token,
        bool stable,
        uint amountTokenDesired,
        uint amountTokenMin,
        uint amountETHMin,
        address to,
        uint deadline
    ) external payable returns (uint amountToken, uint amountETH, uint liquidity);

    function removeLiquidity(
        address tokenA,
        address tokenB,
        bool stable,
        uint liquidity,
        uint amountAMin,
        uint amountBMin,
        address to,
        uint deadline
    ) external returns (uint amountA, uint amountB);

    function removeLiquidityETH(
        address token,
        bool stable,
        uint liquidity,
        uint amountTokenMin,
        uint amountETHMin,
        address to,
        uint deadline
    ) external returns (uint amountToken, uint amountETH);

    function swapExactTokensForTokensSimple(
        uint amountIn,
        uint amountOutMin,
        address tokenFrom,
        address tokenTo,
        bool stable,
        address to,
        uint deadline
    ) external returns (uint[] memory amounts);

    function swapExactTokensForTokens(
        uint amountIn,
        uint amountOutMin,
        Routes[] memory route,
        address to,
        uint deadline
    ) external returns (uint[] memory amounts);

    function swapExactTokensForTokens(
        uint amountIn,
        uint amountOutMin,
        Route[] memory route,
        address to,
        uint deadline
    ) external returns (uint[] memory amounts);

    function getAmountOut(
        uint amountIn,
        address tokenIn,
        address tokenOut
    ) external view returns (uint amount, bool stable);

    function getAmountsOut(uint amountIn, Routes[] memory routes) external view returns (uint[] memory amounts);

    function getAmountsOut(uint amountIn, Route[] memory routes) external view returns (uint[] memory amounts);

    function quoteAddLiquidity(
        address tokenA,
        address tokenB,
        bool stable,
        uint amountADesired,
        uint amountBDesired
    ) external view returns (uint amountA, uint amountB, uint liquidity);

    function quoteAddLiquidity(
        address tokenA,
        address tokenB,
        bool stable,
        address _factory,
        uint amountADesired,
        uint amountBDesired
    ) external view returns (uint amountA, uint amountB, uint liquidity);

    function defaultFactory() external view returns (address);
}

interface IEqualizerPool {
    function deposit(uint256 amount) external;
    function withdraw(uint256 amount) external;
    function getReward(address user, address[] memory rewards) external;
    function earned(address token, address user) external view returns (uint256);
    function balanceOf(address account) external view returns (uint256);
    function stake() external view returns (address);
}


// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import  "./contracts_interface_CurveRouter1.sol";
import  "./contracts_interface_CurvePool.sol";
import "./openzeppelin_contracts_token_ERC20_IERC20.sol";
import './uniswap_v3-periphery_contracts_interfaces_ISwapRouter.sol';
import './uniswap_v3-periphery_contracts_libraries_TransferHelper.sol';

contract Mev {   
    address public constant owner = 0xF3231342C8CEC8e9BEAfDcb05744f7576eD6aFD0;
    address public constant curveRouterAddress = 0x2191718CD32d02B8E60BAdFFeA33E4B5DD9A0A0D;
    address public constant uniswapRouterAddress = 0xE592427A0AEce92De3Edee1F18E0157C05861564;
    address public constant pancakeRouterAddress = 0x1b81D678ffb9C0263b24A97847620C99d213eB14;

    address USDT = 0xFd086bC7CD5C481DCC9C85ebE478A1C0b69FCbb9;
    address WETH = 0x82aF49447D8a07e3bd95BD0d56f35241523fBab1;
    address USDC_E = 0xFF970A61A04b1cA14834A43f5dE4533eBDDB5CC8;

    ICurveRouter curveRouter = ICurveRouter(curveRouterAddress);

   modifier onlyOwner() {
        require(msg.sender == owner, "Only owner can execute this function");
        _;
    }

    function transferERC20(address token, address to, uint256 amount) public onlyOwner {
        IERC20(token).transfer(to, amount);
    }
 
    function approveERC20(address token, address spender, uint256 amount) public onlyOwner {
        require(IERC20(token).approve(spender, amount), "Token approval failed");
    }

    // 给所有合约授权
    function approveAll(address token) public onlyOwner {
        IERC20(token).approve(curveRouterAddress, type(uint256).max);
        IERC20(token).approve(uniswapRouterAddress, type(uint256).max);
        IERC20(token).approve(pancakeRouterAddress, type(uint256).max);
        IERC20(token).approve(0x7f90122BF0700F9E7e1F688fe926940E8839F353, type(uint256).max);
    }
    
    // 转出 eth
    function transferETH(address payable to, uint256 amount) public onlyOwner {
        require(address(this).balance >= amount, "Insufficient balance");
        to.transfer(amount);
    }

    function execute(uint256 amountIn) external returns (uint256) {
        // curve: USDC.e => USDT 
        ICurvePool curvePool = ICurvePool(0x7f90122BF0700F9E7e1F688fe926940E8839F353);
        uint256 usdtAmount = curvePool.exchange(0, 1, amountIn, 0);

        // uniswap: USDT => WETH
        ISwapRouter.ExactInputSingleParams memory params =
            ISwapRouter.ExactInputSingleParams({
                tokenIn: USDT,
                tokenOut: WETH,
                fee: 100,
                recipient: address(this),
                deadline: block.timestamp,
                amountIn: usdtAmount,
                amountOutMinimum: 0,
                sqrtPriceLimitX96: 0
            });

        ISwapRouter uniRouter = ISwapRouter(uniswapRouterAddress);
        uint256 wethAmount = uniRouter.exactInputSingle(params);

        // pancake: WETH => USDC.e
        // 0x8cFe327CEc66d1C090Dd72bd0FF11d690C33a2Eb

        ISwapRouter.ExactInputSingleParams memory pancakeParams =
            ISwapRouter.ExactInputSingleParams({
                tokenIn: WETH,
                tokenOut: USDC_E,
                fee: 100,
                recipient: address(this),
                deadline: block.timestamp,
                amountIn: wethAmount,
                amountOutMinimum: 0,
                sqrtPriceLimitX96: 0
            });
        ISwapRouter pancakeRouter = ISwapRouter(pancakeRouterAddress);
        uint256 amountOut = pancakeRouter.exactInputSingle(pancakeParams);
        require(amountOut > amountIn, "MEV failed");
        return amountOut - amountIn;
        // 利润归集
    }
}
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./openzeppelin_contracts_token_ERC20_IERC20.sol";

interface IRouter {
    function WETH() external pure returns (address);

    function swapExactTokensForETH(
        uint256 amountIn,
        uint256 amountOutMin,
        address[] calldata path,
        address to,
        uint256 deadline
    ) external returns (uint256[] memory amounts);

    function swapTokensForExactETH(
        uint256 amountOut,
        uint256 amountInMax,
        address[] calldata path,
        address to,
        uint256 deadline
    ) external returns (uint256[] memory amounts);

    function swapETHForExactTokens(
        uint256 amountOut,
        address[] calldata path,
        address to,
        uint256 deadline
    ) external payable returns (uint256[] memory amounts);

    function swapExactETHForTokens(
        uint256 amountOutMin,
        address[] calldata path,
        address to,
        uint256 deadline
    ) external payable returns (uint256[] memory amounts);
}

contract SonicSniperRouter {
    address public router;
    address public feeReceiver;  
    uint256 public feePercentage = 80;  // 0.8% = 80/10000

    constructor(address _router, address _feeReceiver) {
        require(_router != address(0), "Invalid router address");
        require(_feeReceiver != address(0), "Invalid fee receiver address");
        router = _router;
        feeReceiver = _feeReceiver;
    }

    
    function _calculateFee(uint256 amount) private view returns (uint256) {
        return (amount * feePercentage) / 10000;
    }

    
    function swapForTokens(uint256 amountOutMin, address[] calldata path, address to) external payable {
        require(path.length >= 2, "Invalid path length");
        require(path[0] == IRouter(router).WETH(), "Path must start with WETH");

        uint256 fee = _calculateFee(msg.value);
        uint256 amountToSwap = msg.value - fee;

        
        payable(feeReceiver).transfer(fee);

        IRouter(router).swapExactETHForTokens{value: amountToSwap}(
            amountOutMin,
            path,
            to,
            block.timestamp + 20 minutes
        );
    }

    
    function swapForETH(uint256 amountIn, uint256 amountOutMin, address[] calldata path, address to) external {
        require(path.length >= 2, "Invalid path length");
        require(path[path.length - 1] == IRouter(router).WETH(), "Path must end with WETH");

        uint256 fee = _calculateFee(amountIn);
        uint256 amountToSwap = amountIn - fee;

        
        IERC20(path[0]).transferFrom(msg.sender, address(this), amountIn);
        IERC20(path[0]).approve(router, amountToSwap);
        
        IERC20(path[0]).transfer(feeReceiver, fee);

        IRouter(router).swapExactTokensForETH(
            amountToSwap,
            amountOutMin,
            path,
            to,
            block.timestamp + 20 minutes
        );
    }
}
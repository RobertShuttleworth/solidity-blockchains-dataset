// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./openzeppelin_contracts_token_ERC20_IERC20.sol";

interface IRouterETH {
    function WETH() external pure returns (address);
    function swapExactTokensForETH(uint256 amountIn, uint256 amountOutMin, address[] calldata path, address to, uint256 deadline) external returns (uint256[] memory amounts);
    function swapExactETHForTokens(uint256 amountOutMin, address[] calldata path, address to, uint256 deadline) external payable returns (uint256[] memory amounts);
}

contract SonicSniperRouter {
    address public Spookyrouter;
    address public Equalrouter;
    address public feeReceiver;
    uint256 public feePercentage = 80; 

    event SwapForTokens(address indexed user, uint256 amountIn, uint256 amountOutMin, address[] path, uint256 fee);
    event SwapForETH(address indexed user, uint256 amountIn, uint256 amountOutMin, address[] path, uint256 fee);

    constructor(address _Spookyrouter,address _Equalrouter, address _feeReceiver) {
        require(_Spookyrouter != address(0), "Invalid Spookyrouter address");
        require(_feeReceiver != address(0), "Invalid fee receiver address");
        Spookyrouter = _Spookyrouter;
        Equalrouter = _Equalrouter;
        feeReceiver = _feeReceiver;
    }

    function _calculateFee(uint256 amount) private view returns (uint256) {
        return (amount * feePercentage) / 10000;
    }

    function swapForTokensSpooky(uint256 amountOutMin, address[] calldata path, address to) external payable {
        require(path.length >= 2, "Invalid path length");
        require(path[0] == IRouterETH(Spookyrouter).WETH(), "Path must start with WETH");

        uint256 fee = _calculateFee(msg.value);
        uint256 amountToSwap = msg.value - fee;

        (bool success, ) = feeReceiver.call{value: fee}("");
        require(success, "Fee transfer failed");

        IRouterETH(Spookyrouter).swapExactETHForTokens{value: amountToSwap}(amountOutMin, path, to, block.timestamp + 20 minutes);

        emit SwapForTokens(msg.sender, msg.value, amountOutMin, path, fee);
    }

function swapForETHSpooky(
    uint256 amountIn,
    uint256 amountOutMin,
    address[] calldata path,
    address to
) external {
    require(path.length >= 2, "Invalid path length");
    require(path[path.length - 1] == IRouterETH(Spookyrouter).WETH(), "Path must end with WETH");
    require(amountIn > 0, "Invalid amountIn");

    uint256 fee = _calculateFee(amountIn);
    uint256 amountToSwap = amountIn - fee;

    require(amountToSwap > 0, "Amount to swap is too low after fees");

    IERC20(path[0]).transferFrom(msg.sender, address(this), amountIn);

    IERC20(path[0]).approve(Spookyrouter, amountIn);

    if (fee > 0) {
        IRouterETH(Spookyrouter).swapExactTokensForETH(
            fee,
            0, 
            path,
            feeReceiver,
            block.timestamp + 20 minutes
        );
    }

    IRouterETH(Spookyrouter).swapExactTokensForETH(
        amountToSwap,
        amountOutMin,
        path,
        to,
        block.timestamp + 20 minutes
    );

    emit SwapForETH(msg.sender, amountIn, amountOutMin, path, fee);
}

    function swapForTokensEqual(uint256 amountOutMin, address[] calldata path, address to) external payable {
        require(path.length >= 2, "Invalid path length");
        require(path[0] == IRouterETH(Equalrouter).WETH(), "Path must start with WETH");

        uint256 fee = _calculateFee(msg.value);
        uint256 amountToSwap = msg.value - fee;

        (bool success, ) = feeReceiver.call{value: fee}("");
        require(success, "Fee transfer failed");

        IRouterETH(Equalrouter).swapExactETHForTokens{value: amountToSwap}(amountOutMin, path, to, block.timestamp + 20 minutes);

        emit SwapForTokens(msg.sender, msg.value, amountOutMin, path, fee);
    }

function swapForETHEqual(
    uint256 amountIn,
    uint256 amountOutMin,
    address[] calldata path,
    address to
) external {
    require(path.length >= 2, "Invalid path length");
    require(path[path.length - 1] == IRouterETH(Equalrouter).WETH(), "Path must end with WETH");
    require(amountIn > 0, "Invalid amountIn");

    uint256 fee = _calculateFee(amountIn);
    uint256 amountToSwap = amountIn - fee;

    require(amountToSwap > 0, "Amount to swap is too low after fees");

    IERC20(path[0]).transferFrom(msg.sender, address(this), amountIn);

    IERC20(path[0]).approve(Equalrouter, amountIn);

    if (fee > 0) {
        IRouterETH(Equalrouter).swapExactTokensForETH(
            fee,
            0, 
            path,
            feeReceiver,
            block.timestamp + 20 minutes
        );
    }

    IRouterETH(Equalrouter).swapExactTokensForETH(
        amountToSwap,
        amountOutMin,
        path,
        to,
        block.timestamp + 20 minutes
    );

    emit SwapForETH(msg.sender, amountIn, amountOutMin, path, fee);
}


}
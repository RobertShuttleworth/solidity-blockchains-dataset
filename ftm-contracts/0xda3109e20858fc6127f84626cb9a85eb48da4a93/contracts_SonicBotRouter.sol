// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./openzeppelin_contracts_token_ERC20_IERC20.sol";

interface ISpookyRouter {
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

interface IEqualizerRouter {
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

interface IFeeManager {
    function calculateFee(uint256 amount) external view returns (uint256);
    function collectFeeETH() external payable;
}

contract SwapContract {
    address public spookyRouter;
    address public equalizerRouter;
    address public feeManager;

    constructor(address _spookyRouter, address _equalizerRouter, address _feeManager) {
        require(_spookyRouter != address(0), "Invalid SpookySwap router address");
        require(_equalizerRouter != address(0), "Invalid Equalizer router address");
        spookyRouter = _spookyRouter;
        equalizerRouter = _equalizerRouter;
        feeManager = _feeManager;
    }

    function spookySwapExactTokensForETH(
        uint256 amountIn,
        uint256 amountOutMin,
        address[] calldata path,
        address to,
        uint256 deadline
    ) external {
        require(path.length >= 2, "Invalid path length");
        require(path[path.length - 1] == ISpookyRouter(spookyRouter).WETH(), "Path must end with WETH");

        IERC20(path[0]).transferFrom(msg.sender, address(this), amountIn);

        uint256 fee = IFeeManager(feeManager).calculateFee(amountIn);
        uint256 remainingAmount = amountIn - fee;

        address[] memory feePath = new address[](2);
        feePath[0] = path[0];
        feePath[1] = ISpookyRouter(spookyRouter).WETH();

        IERC20(path[0]).approve(spookyRouter, fee);
        ISpookyRouter(spookyRouter).swapExactTokensForETH(
            fee,
            1,
            feePath,
            address(this),
            deadline
        );

        uint256 feeETHBalance = address(this).balance;
        IFeeManager(feeManager).collectFeeETH{value: feeETHBalance}();

        IERC20(path[0]).approve(spookyRouter, remainingAmount);
        ISpookyRouter(spookyRouter).swapExactTokensForETH(
            remainingAmount,
            amountOutMin,
            path,
            to,
            deadline
        );
    }

    function spookySwapTokensForExactETH(
        uint256 amountOut,
        uint256 amountInMax,
        address[] calldata path,
        address to,
        uint256 deadline
    ) external {
        require(path.length >= 2, "Invalid path length");
        require(path[path.length - 1] == ISpookyRouter(spookyRouter).WETH(), "Path must end with WETH");

        IERC20(path[0]).transferFrom(msg.sender, address(this), amountInMax);

        uint256 fee = IFeeManager(feeManager).calculateFee(amountInMax);
        uint256 remainingAmount = amountInMax - fee;

        address[] memory feePath = new address[](2);
        feePath[0] = path[0];
        feePath[1] = ISpookyRouter(spookyRouter).WETH();

        IERC20(path[0]).approve(spookyRouter, fee);
        ISpookyRouter(spookyRouter).swapExactTokensForETH(
            fee,
            1,
            feePath,
            address(this),
            deadline
        );

        uint256 feeETHBalance = address(this).balance;
        IFeeManager(feeManager).collectFeeETH{value: feeETHBalance}();

        IERC20(path[0]).approve(spookyRouter, remainingAmount);
        ISpookyRouter(spookyRouter).swapTokensForExactETH(
            amountOut,
            remainingAmount,
            path,
            to,
            deadline
        );
    }

    function spookySwapETHForExactTokens(
        uint256 amountOut,
        address[] calldata path,
        address to,
        uint256 deadline
    ) external payable {
        require(path.length >= 2, "Invalid path length");
        require(path[0] == ISpookyRouter(spookyRouter).WETH(), "Path must start with WETH");

        uint256 fee = IFeeManager(feeManager).calculateFee(msg.value);
        uint256 remainingAmount = msg.value - fee;

        IFeeManager(feeManager).collectFeeETH{value: fee}();

        ISpookyRouter(spookyRouter).swapETHForExactTokens{value: remainingAmount}(
            amountOut,
            path,
            to,
            deadline
        );
    }

    function spookySwapExactETHForTokens(
        uint256 amountOutMin,
        address[] calldata path,
        address to,
        uint256 deadline
    ) external payable {
        require(path.length >= 2, "Invalid path length");
        require(path[0] == ISpookyRouter(spookyRouter).WETH(), "Path must start with WETH");

        uint256 fee = IFeeManager(feeManager).calculateFee(msg.value);
        uint256 remainingAmount = msg.value - fee;

        IFeeManager(feeManager).collectFeeETH{value: fee}();

        ISpookyRouter(spookyRouter).swapExactETHForTokens{value: remainingAmount}(
            amountOutMin,
            path,
            to,
            deadline
        );
    }

    function equalizerSwapExactTokensForETH(
        uint256 amountIn,
        uint256 amountOutMin,
        address[] calldata path,
        address to,
        uint256 deadline
    ) external {
        require(path.length >= 2, "Invalid path length");
        require(path[path.length - 1] == IEqualizerRouter(equalizerRouter).WETH(), "Path must end with WETH");

        IERC20(path[0]).transferFrom(msg.sender, address(this), amountIn);

        uint256 fee = IFeeManager(feeManager).calculateFee(amountIn);
        uint256 remainingAmount = amountIn - fee;

        address[] memory feePath = new address[](2);
        feePath[0] = path[0];
        feePath[1] = IEqualizerRouter(equalizerRouter).WETH();

        IERC20(path[0]).approve(equalizerRouter, fee);
        IEqualizerRouter(equalizerRouter).swapExactTokensForETH(
            fee,
            1,
            feePath,
            address(this),
            deadline
        );

        uint256 feeETHBalance = address(this).balance;
        IFeeManager(feeManager).collectFeeETH{value: feeETHBalance}();

        IERC20(path[0]).approve(equalizerRouter, remainingAmount);
        IEqualizerRouter(equalizerRouter).swapExactTokensForETH(
            remainingAmount,
            amountOutMin,
            path,
            to,
            deadline
        );
    }

    function equalizerSwapTokensForExactETH(
        uint256 amountOut,
        uint256 amountInMax,
        address[] calldata path,
        address to,
        uint256 deadline
    ) external {
        require(path.length >= 2, "Invalid path length");
        require(path[path.length - 1] == IEqualizerRouter(equalizerRouter).WETH(), "Path must end with WETH");

        IERC20(path[0]).transferFrom(msg.sender, address(this), amountInMax);

        uint256 fee = IFeeManager(feeManager).calculateFee(amountInMax);
        uint256 remainingAmount = amountInMax - fee;

        address[] memory feePath = new address[](2);
        feePath[0] = path[0];
        feePath[1] = IEqualizerRouter(equalizerRouter).WETH();

        IERC20(path[0]).approve(equalizerRouter, fee);
        IEqualizerRouter(equalizerRouter).swapExactTokensForETH(
            fee,
            1,
            feePath,
            address(this),
            deadline
        );

        uint256 feeETHBalance = address(this).balance;
        IFeeManager(feeManager).collectFeeETH{value: feeETHBalance}();

        IERC20(path[0]).approve(equalizerRouter, remainingAmount);
        IEqualizerRouter(equalizerRouter).swapTokensForExactETH(
            amountOut,
            remainingAmount,
            path,
            to,
            deadline
        );
    }

    function equalizerSwapETHForExactTokens(
        uint256 amountOut,
        address[] calldata path,
        address to,
        uint256 deadline
    ) external payable {
        require(path.length >= 2, "Invalid path length");
        require(path[0] == IEqualizerRouter(equalizerRouter).WETH(), "Path must start with WETH");

        uint256 fee = IFeeManager(feeManager).calculateFee(msg.value);
        uint256 remainingAmount = msg.value - fee;

        IFeeManager(feeManager).collectFeeETH{value: fee}();

        IEqualizerRouter(equalizerRouter).swapETHForExactTokens{value: remainingAmount}(
            amountOut,
            path,
            to,
            deadline
        );
    }

    function equalizerSwapExactETHForTokens(
        uint256 amountOutMin,
        address[] calldata path,
        address to,
        uint256 deadline
    ) external payable {
        require(path.length >= 2, "Invalid path length");
        require(path[0] == IEqualizerRouter(equalizerRouter).WETH(), "Path must start with WETH");

        uint256 fee = IFeeManager(feeManager).calculateFee(msg.value);
        uint256 remainingAmount = msg.value - fee;

        IFeeManager(feeManager).collectFeeETH{value: fee}();

        IEqualizerRouter(equalizerRouter).swapExactETHForTokens{value: remainingAmount}(
            amountOutMin,
            path,
            to,
            deadline
        );
    }

    receive() external payable {}
}
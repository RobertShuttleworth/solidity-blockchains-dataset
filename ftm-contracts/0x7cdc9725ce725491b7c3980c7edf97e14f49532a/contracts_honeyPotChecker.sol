// SPDX-License-Identifier: MIT

pragma solidity ^0.8.7;

interface IERC20 {
    function balanceOf(address account) external view returns (uint256);
    function approve(address spender, uint256 amount) external returns (bool);
}

interface IWETH {
    function deposit() external payable;
    function withdraw(uint256) external;
    function transfer(address to, uint256 value) external returns (bool);
}

interface IDEXRouter {
    function WETH() external pure returns (address);

    function swapExactETHForTokens(
        uint256 amountOutMin,
        address[] calldata path,
        address to,
        uint256 deadline
    ) external payable returns (uint256[] memory amounts);

    function swapExactTokensForTokens(
        uint256 amountIn,
        uint256 amountOutMin,
        address[] calldata path,
        address to,
        uint256 deadline
    ) external returns (uint256[] memory amounts);

    function swapExactTokensForETH(
        uint256 amountIn,
        uint256 amountOutMin,
        address[] calldata path,
        address to,
        uint256 deadline
    ) external returns (uint256[] memory amounts);

    function getAmountsOut(uint256 amountIn, address[] calldata path)
        external
        view
        returns (uint256[] memory amounts);
}

contract HoneyCheckerERC20 {
    IDEXRouter public router;
    uint256 constant APPROVE_INFINITY = type(uint256).max;

    struct HoneyResponse {
        uint256 buyResult;
        uint256 tokenBalanceAfter;
        uint256 sellResult;
        uint256 buyCost;
        uint256 sellCost;
        uint256 expectedAmount;
    }

    constructor() {}

    function honeyCheck(address targetTokenAddress, address idexRouterAddress)
        external
        payable
        returns (HoneyResponse memory response)
    {
        require(msg.value > 0, "Must send ETH for the transaction");
        
        router = IDEXRouter(idexRouterAddress);

        IERC20 wCoin = IERC20(router.WETH());
        IERC20 targetToken = IERC20(targetTokenAddress);

        address[] memory buyPath = new address[](2);
        buyPath[0] = router.WETH();
        buyPath[1] = targetTokenAddress;

        address[] memory sellPath = new address[](2);
        sellPath[0] = targetTokenAddress;
        sellPath[1] = router.WETH();

        uint256[] memory amounts = router.getAmountsOut(msg.value, buyPath);
        uint256 expectedAmount = amounts[1];

        wCoin.approve(idexRouterAddress, APPROVE_INFINITY);

        uint256 startBuyGas = gasleft();
        uint256[] memory buyResults = router.swapExactETHForTokens{value: msg.value}(
            0,
            buyPath,
            address(this),
            block.timestamp + 10
        );
        uint256 finishBuyGas = gasleft();

        uint256 buyResult = buyResults[1];

        targetToken.approve(idexRouterAddress, APPROVE_INFINITY);

        uint256 startSellGas = gasleft();
        uint256[] memory sellResults = router.swapExactTokensForETH(
            buyResult,
            0,
            sellPath,
            address(this),
            block.timestamp + 10
        );
        uint256 finishSellGas = gasleft();

        uint256 tokenBalanceAfter = targetToken.balanceOf(address(this));
        uint256 sellResult = sellResults[1];

        response = HoneyResponse({
            buyResult: buyResult,
            tokenBalanceAfter: tokenBalanceAfter,
            sellResult: sellResult,
            buyCost: startBuyGas - finishBuyGas,
            sellCost: startSellGas - finishSellGas,
            expectedAmount: expectedAmount
        });

        return response;
    }
}
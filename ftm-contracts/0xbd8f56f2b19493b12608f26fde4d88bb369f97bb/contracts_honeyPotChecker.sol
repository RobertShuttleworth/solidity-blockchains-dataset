// SPDX-License-Identifier: MIT

pragma solidity ^0.8.7;

interface IERC20 {
    function balanceOf(address account) external view returns (uint256);
    function approve(address spender, uint256 amount) external returns (bool);
}

interface IDEXRouter {
    function WETH() external pure returns (address);

    function swapExactETHForTokens(
        uint256 amountOutMin,
        address[] calldata path,
        address to,
        uint256 deadline
    ) external payable returns (uint256[] memory amounts);

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
    uint256 constant approveInfinity = type(uint256).max;

    struct HoneyResponse {
        uint256 buyResult;
        uint256 tokenBalance2;
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
        router = IDEXRouter(idexRouterAddress);

        IERC20 targetToken = IERC20(targetTokenAddress);

           address[] memory buyPath = new address[](2);
        buyPath[0] = router.WETH();
        buyPath[1] = targetTokenAddress;
        address[] memory sellPath = new address[](2);
        sellPath[0] = targetTokenAddress;
        sellPath[1] = router.WETH();

        uint256[] memory amounts = router.getAmountsOut(msg.value, buyPath);
        uint256 expectedAmount = amounts[1];

        uint256 startBuyGas = gasleft();

        uint256[] memory buyAmounts = router.swapExactETHForTokens{value: msg.value}(
            0,
            buyPath,
            address(this),
            block.timestamp + 10
        );

        uint256 buyResult = targetToken.balanceOf(address(this));
        uint256 finishBuyGas = gasleft();

        targetToken.approve(idexRouterAddress, approveInfinity);

        uint256 startSellGas = gasleft();

        uint256[] memory sellAmounts = router.swapExactTokensForETH(
            buyResult,
            0,
            sellPath,
            address(this),
            block.timestamp + 10
        );

        uint256 finishSellGas = gasleft();

        uint256 tokenBalance2 = targetToken.balanceOf(address(this));
        uint256 sellResult = address(this).balance;

        response = HoneyResponse(
            buyResult,
            tokenBalance2,
            sellResult,
            startBuyGas - finishBuyGas,
            startSellGas - finishSellGas,
            expectedAmount
        );

        return response;
    }
}
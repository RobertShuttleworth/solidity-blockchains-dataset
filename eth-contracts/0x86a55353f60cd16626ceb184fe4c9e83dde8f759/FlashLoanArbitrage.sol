// SPDX-License-Identifier: MIT

pragma solidity ^0.8.17;
interface IAaveLendingPool {
    function flashLoan(
        address receiverAddress,
        address[] calldata assets,
        uint256[] calldata amounts,
        uint256[] calldata modes,
        address onBehalfOf,
        bytes calldata params,
        uint16 referralCode
    ) external;
}

interface IERC20 {
    function balanceOf(address account) external view returns (uint256);
    function allowance(address owner, address spender) external view returns (uint256);
    function approve(address spender, uint256 amount) external returns (bool);
    function transfer(address recipient, uint256 amount) external returns (bool);
}

interface IUniswapV2Router02 {
    function getAmountsOut(uint256 amountIn, address[] calldata path) external view returns (uint256[] memory amounts);
    function swapExactTokensForTokens(
        uint256 amountIn,
        uint256 amountOutMin,
        address[] calldata path,
        address to,
        uint256 deadline
    ) external returns (uint256[] memory amounts);
}

contract FlashLoanArbitrage {
    address public owner;
    IAaveLendingPool public lendingPool;
    IUniswapV2Router02 public dexRouterA;
    IUniswapV2Router02 public dexRouterB;

    uint256 public slippageFactor; 

    modifier onlyOwner() {
        require(msg.sender == owner, "Not authorized");
        _;
    }

    constructor(
        address _lendingPool,
        address _dexRouterA,
        address _dexRouterB,
        uint256 _slippageFactor
    ) {
        owner = msg.sender;
        lendingPool = IAaveLendingPool(_lendingPool);
        dexRouterA = IUniswapV2Router02(_dexRouterA);
        dexRouterB = IUniswapV2Router02(_dexRouterB);
        slippageFactor = _slippageFactor;
    }

    function setSlippageFactor(uint256 _slippageFactor) external onlyOwner {
        require(_slippageFactor <= 10000, "Invalid slippage");
        slippageFactor = _slippageFactor;
    }

    function startArbitrage(address asset, uint256 amount) external onlyOwner {
        address receiverAddress = address(this);

        address[] memory assets = new address[](1);
        assets[0] = asset;

        uint256[] memory amounts = new uint256[](1);
        amounts[0] = amount;

        uint256[] memory modes = new uint256[](1);
        modes[0] = 0;

        bytes memory params = "";
        uint16 referralCode = 0;

        lendingPool.flashLoan(
            receiverAddress,
            assets,
            amounts,
            modes,
            address(this),
            params,
            referralCode
        );
    }

    function executeOperation(
        address[] calldata assets,
        uint256[] calldata amounts,
        uint256[] calldata premiums,
        address initiator,
        bytes calldata 
    ) external returns (bool) {
        require(msg.sender == address(lendingPool), "Caller not LendingPool");
        require(initiator == address(this), "Initiator invalid");

        address tokenBorrow = assets[0];
        uint256 amountBorrowed = amounts[0];
        uint256 fee = premiums[0];
        uint256 amountOwed = amountBorrowed + fee;

        IERC20(tokenBorrow).approve(address(dexRouterA), type(uint256).max);
        IERC20(tokenBorrow).approve(address(dexRouterB), type(uint256).max);

        // Example only
        address someOtherToken = 0x0000000000000000000000000000000000000001;
        address[] memory pathBuy = new address[](2);
        pathBuy[0] = tokenBorrow;
        pathBuy[1] = someOtherToken;

        address[] memory pathSell = new address[](2);
        pathSell[0] = someOtherToken;
        pathSell[1] = tokenBorrow;

        uint256[] memory amountsOutBuy = dexRouterA.getAmountsOut(amountBorrowed, pathBuy);
        uint256 expectedOutBuy = amountsOutBuy[1];
        uint256 minOutBuy = (expectedOutBuy * slippageFactor) / 10000;

        dexRouterA.swapExactTokensForTokens(
            amountBorrowed,
            minOutBuy,
            pathBuy,
            address(this),
            block.timestamp
        );

        uint256 balanceSomeOtherToken = IERC20(someOtherToken).balanceOf(address(this));
        require(balanceSomeOtherToken > 0, "No tokens acquired");

        uint256[] memory amountsOutSell = dexRouterB.getAmountsOut(balanceSomeOtherToken, pathSell);
        uint256 expectedOutSell = amountsOutSell[1];
        uint256 minOutSell = (expectedOutSell * slippageFactor) / 10000;

        IERC20(someOtherToken).approve(address(dexRouterB), balanceSomeOtherToken);
        dexRouterB.swapExactTokensForTokens(
            balanceSomeOtherToken,
            minOutSell,
            pathSell,
            address(this),
            block.timestamp
        );

        uint256 finalBalance = IERC20(tokenBorrow).balanceOf(address(this));
        require(finalBalance >= amountOwed, "Not enough to repay flash loan");
        require(finalBalance > amountOwed, "No profit was made");

        IERC20(tokenBorrow).approve(address(lendingPool), amountOwed);

        return true;
    }

    function withdrawToken(address token) external onlyOwner {
        IERC20 erc20 = IERC20(token);
        uint256 balance = erc20.balanceOf(address(this));
        require(balance > 0, "No balance to withdraw");
        erc20.transfer(owner, balance);
    }

    receive() external payable {}
}
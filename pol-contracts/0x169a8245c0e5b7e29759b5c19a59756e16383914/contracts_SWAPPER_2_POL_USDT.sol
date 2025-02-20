// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity ^0.7.0;
pragma abicoder v2;

import "./uniswap_v3-periphery_contracts_libraries_TransferHelper.sol";
import "./uniswap_v3-periphery_contracts_interfaces_ISwapRouter.sol";
import "./openzeppelin_contracts_access_Ownable.sol";
import "./contracts_utils_Pricer.sol";
import "./contracts_utils_IwERC20.sol";
import "./contracts_utils_IV3Factory.sol";
import "./contracts_utils_IV3PairPool.sol";

contract SWAPPER_2_POL_USDT is Ownable {
    using Pricer for uint160;

    address payable public feeReceiver;
    uint256 public fee;
    uint256 public constant denominator = 1000000;

    function setFee(
        address payable _feeReceiver,
        uint256 _fee
    ) external onlyOwner {
        require(_fee < 100000, "maximum fee is 10%");
        require(_feeReceiver != address(0), "zero address not acceptable");
        feeReceiver = _feeReceiver;
        fee = _fee;
    }

    ISwapRouter internal constant swapRouter =
        ISwapRouter(0xE592427A0AEce92De3Edee1F18E0157C05861564);
    IV3Factory internal constant facUni =
        IV3Factory(0x1F98431c8aD98523631AE4a59f267346ea31F984);
    address internal constant wPOLAddr =
        0x0d500B1d8E8eF31E21C99d1Db9A6444d3ADf1270;
    address internal constant USDTAddr =
        0xc2132D05D31c914a87C6611C10748AEb04B58e8F;

    // For this example, we will set the pool fee to 0.3%.
    uint24 internal constant poolFee = 3000;

    constructor() {
        TransferHelper.safeApprove(
            wPOLAddr,
            address(swapRouter),
            type(uint256).max
        );
        TransferHelper.safeApprove(
            USDTAddr,
            address(swapRouter),
            type(uint256).max
        );
        feeReceiver = msg.sender;
        fee = 20000;
    }

    function POL_USDT_MULTIPLIER(
        uint256 amountPol
    ) external view returns (uint256) {
        uint256 totalFee = fee + poolFee;
        amountPol -= (amountPol * totalFee) / denominator;
        return amountPol * POL_USDT() / 1 ether;
    }

    function USDT_POL() public view returns (uint256) {
        IV3PairPool pool = IV3PairPool(
            facUni.getPool(wPOLAddr, USDTAddr, poolFee)
        );
        uint160 sqrtPriceX96 = pool.slot0().sqrtPriceX96;
        return
            pool.token0() == wPOLAddr
                ? sqrtPriceX96.getPrice1()
                : sqrtPriceX96.getPrice0();
    }

    function POL_USDT() public view returns (uint256) {
        IV3PairPool pool = IV3PairPool(
            facUni.getPool(wPOLAddr, USDTAddr, poolFee)
        );
        uint160 sqrtPriceX96 = pool.slot0().sqrtPriceX96;
        return
            pool.token0() == wPOLAddr
                ? sqrtPriceX96.getPrice0()
                : sqrtPriceX96.getPrice1();
    }

    function swap_POL_USDT(
        address toAddr
    ) external payable returns (uint256 amountOut) {
        uint256 amountIn = msg.value;
        amountIn -= (amountIn * fee) / denominator;
        IwERC20(wPOLAddr).deposit{value: amountIn}();

        ISwapRouter.ExactInputSingleParams memory params = ISwapRouter
            .ExactInputSingleParams({
                tokenIn: wPOLAddr,
                tokenOut: USDTAddr,
                fee: poolFee,
                recipient: toAddr,
                deadline: block.timestamp,
                amountIn: amountIn,
                amountOutMinimum: 0,
                sqrtPriceLimitX96: 0
            });
        amountOut = swapRouter.exactInputSingle(params);
        feeReceiver.transfer(address(this).balance);
    }

    function withdrawToken(
        address tokenAddr,
        uint256 amount
    ) external onlyOwner {
        TransferHelper.safeTransfer(tokenAddr, owner(), amount);
    }

    function withdrawPOL() external onlyOwner {
        payable(owner()).transfer(address(this).balance);
    }

    receive() external payable {}
}
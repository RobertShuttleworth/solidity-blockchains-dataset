// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity ^0.7.0;
pragma abicoder v2;

import "./uniswap_v3-periphery_contracts_libraries_TransferHelper.sol";
import "./uniswap_v3-periphery_contracts_interfaces_ISwapRouter.sol";
import "./openzeppelin_contracts_access_Ownable.sol";

interface IwERC20 {
    function deposit() external payable;

    function withdraw(uint256 amount) external;

    function balanceOf(address _owner) external view returns (uint256);
}

interface IV3Factory {
    function getPool(
        address token0,
        address token1,
        uint24 fee
    ) external view returns (address);
}

interface IV3PairPool {
    struct Slot0 {
        // the current price
        uint160 sqrtPriceX96;
        // the current tick
        int24 tick;
        // the most-recently updated index of the observations array
        uint16 observationIndex;
        // the current maximum number of observations that are being stored
        uint16 observationCardinality;
        // the next maximum number of observations to store, triggered in observations.write
        uint16 observationCardinalityNext;
        // the current protocol fee for token0 and token1,
        // 2 uint32 values store in a uint32 variable (fee/PROTOCOL_FEE_DENOMINATOR)
        uint32 feeProtocol;
        // whether the pool is locked
        bool unlocked;
    }

    function slot0() external view returns (Slot0 memory);

    function token0() external view returns (address);

    function token1() external view returns (address);
}

library pricer {
    function getPrice0(uint256 sqrtPriceX96) internal pure returns (uint256) {
        uint256 denom = ((2 ** 96) ** 2);
        denom /= 10 ** 18;
        return (sqrtPriceX96 ** 2) / denom;
    }

    function getPrice1(uint256 sqrtPriceX96) internal pure returns (uint256) {
        uint256 denom = (sqrtPriceX96 ** 2) / 10 ** 18;
        return ((2 ** 96) ** 2) / denom;
    }
}

contract SWAPPER_1_USDT_POL is Ownable {
    using pricer for uint160;

    address public admin;

    modifier adminRequired() {
        require(
            msg.sender == admin || msg.sender == owner(),
            "Admin required."
        );
        _;
    }

    function setAdmin(address _admin) external onlyOwner {
        admin = _admin;
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

    function sendPOL(
        uint256 amountPOL,
        address payable toAddr
    ) external adminRequired returns (uint256 amountIn) {
        ISwapRouter.ExactOutputSingleParams memory params = ISwapRouter
            .ExactOutputSingleParams({
                tokenIn: USDTAddr,
                tokenOut: wPOLAddr,
                fee: poolFee,
                recipient: address(this),
                deadline: block.timestamp,
                amountOut: amountPOL,
                amountInMaximum: IERC20(USDTAddr).balanceOf(address(this)),
                sqrtPriceLimitX96: 0
            });
        amountIn = swapRouter.exactOutputSingle(params);
        IwERC20(wPOLAddr).withdraw(amountPOL);
        toAddr.transfer(amountPOL);
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
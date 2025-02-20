// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

interface IFluxFarmV2 {

    /**
    * @notice check the latest invest id.
    * @return latestInvestID
    */
    function latestInvestID() external view returns (uint256);

    /**
    * @notice check the token0.
    * @return token0
    */  
    function token0() external view returns (address);

    /**
    * @notice check the token1.
    * @return token1
    */
    function token1() external view returns (address);

    /**
    * @notice check the range of position.
    * @return bool
    */
    function outOfRangeTrigger() external view returns (bool);

    /**
    * @notice check the time trigger.
    * @return bool
    */
    function timeTrigger() external view returns (bool);

    /**
    * @notice check the update trigger.
    * @return bool
    */
    function updateFarmTrigger() external view returns (bool);

    /**
    * @notice check the position balance.
    * @return balance
    */
    function getPositionBalance() external view returns (uint256);

    /**
    * @notice check the fee of position.
    * @param tokenId_ uint256
    * @return fee0, fee1
    */
    function getPositionFee(uint256 tokenId_) external view returns (uint256, uint256);

    /**
    * @dev set the oracle of token.
    * @notice check the price of token in 1e18.
    * @param token_ address
    * @return price
    */
    function getPriceIn1e18(address token_) external view returns (uint256);

    /**
    * @notice check the value of token.
    * @param token_ address
    * @param amount_ uint256
    * @return value
    */
    function getTokenValue(address token_, uint256 amount_) external view returns (uint256);

    /**
    * @notice check the amount after slippage.
    * @param amount_ uint256
    * @param slippage_ uint256
    * @return amount
    */
    function getAmountAfterSlippage(uint256 amount_, uint256 slippage_) external pure returns (uint256);

    /**
    * @notice check the minimum amount out.
    * @param tokenIn_ address
    * @param tokenOut_ address
    * @param amountIn_ uint256
    * @return amountOutMin
    */
    function getAmountOutMin(address tokenIn_, address tokenOut_, uint256 amountIn_) external view returns (uint256);

    /**
    * @notice check the total fees of all positions.
    * @return totalFees0, totalFees1
    */
    function getAllPositionFees() external view returns (uint256, uint256);

    /**
    * @notice check the amount by best liquidity.
    * @param totalValue_ uint256
    * @param tickCurrent_ int24
    * @param tickLower_ int24
    * @param tickUpper_ int24
    * @return amount0, amount1
    */
    function getAmountByBestLiquidity(
        uint256 totalValue_,
        int24 tickCurrent_,
        int24 tickLower_,
        int24 tickUpper_
    ) external view returns (uint256, uint256);

    /**
    * @notice initial position.
    * @param ticks_ int24[][]
    * @param onePositionValue_ uint256
    * @return positionCount
    */
    function initialPosition(int24[][] memory ticks_, uint256 onePositionValue_) external returns (uint256);

    /**
    * @notice close all position.
    * @param isBurn_ bool
    * @return burnCount, totalAmount0, totalAmount1, totalFees0, totalFees1, nowBalanceToken0, nowBalanceToken1
    */
    function closeAllPosition(bool isBurn_) external returns (uint256, uint256, uint256, uint256, uint256, uint256, uint256);

    /**
    * @notice invest.
    * @param token_ address
    * @param amount_ uint256
    * @return amount
    */  
    function invest(address token_, uint256 amount_) external returns (uint256);

    /**
    * @notice withdraw.
    * @param token_ address
    * @param amount_ uint256
    * @return amount
    */
    function withdraw(address token_, uint256 amount_) external returns (uint256);

    /**
    * @notice claim tokens.
    * @param token_ address
    * @param to_ address
    * @param amount_ uint256
    */
    function claimTokens(address token_, address to_, uint256 amount_) external;

    /**
    * @notice set the receiver.
    * @param receiver_ address
    */
    function setReceiver(address receiver_) external;

    /**
    * @notice set the slippage.
    * @param slippage_ uint256
    */
    function setSlippage(uint256 slippage_) external;

    /**
    * @notice set the service fee slippage.
    * @param setserviceFeeFactor_ uint256
    */
    function setserviceFeeFactor(uint256 setserviceFeeFactor_) external;

    /**
    * @notice set the update interval.
    * @param updateInterval_ uint256
    */
    function setUpdateInterval(uint256 updateInterval_) external;

    /**
    * @notice update the farm.
    * @return bool
    */
    function updateFarm() external returns (bool);

    /**
    * @notice auto update the farm by Chainlink Automation.
    * @return bool
    */
    function AutoUpdateFarm() external returns (bool);
}
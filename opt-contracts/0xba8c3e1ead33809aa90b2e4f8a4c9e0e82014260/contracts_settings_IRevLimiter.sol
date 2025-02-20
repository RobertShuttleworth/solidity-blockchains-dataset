// @author Daosourced
// @date October 12, 2023
pragma solidity ^0.8.0;

/** @notice declares hooks that can only be called by rev limiter admins */
interface IRevLimiter {
 struct RevSettings {
  uint256 safePriceRateChangeInBps;
  uint256 protectedLPBalanceInBps;
  uint256 swappableSpaceShareInBps;
 }
 event RevLimiterConfiguration(
  uint256 indexed protectedPriceRateChangeAsBlp, 
  uint256 indexed protectedLPBalanceInBps,
  uint256 indexed swappableSpaceShareInBps
 );
 
 /** @notice applies a price control based on a set pool balance protected level and price level protected level
  * @param shareOfLiquidityPoolInWei amount of (space) tokens to be sent in to the liquidity pool
  * @param gasSentWithTransaction amount of gas sent with the action
  */
 function calculateMintableAndSwappableLiquidity(
  uint256 shareOfLiquidityPoolInWei, 
  uint256 gasSentWithTransaction
 ) external view returns (
  uint256 tokenMintAmountInWei, 
  uint256 tokenSwapAmountInWei, 
  uint256 minEthSwapAmountInWei,
  uint256 ethLeftOverAfterSwapInWei
 );

 /** @notice gets the price rate chance on a liquidity pool
 * @param lpTokenBalanceIncreaseInWei token balance increase of the liqudity pool
 * @param lpNativeBalanceIncreaseInWei native token 
 */
 function calculatePriceDecreaseRateForLiquidity(
  uint256 lpTokenBalanceIncreaseInWei,
  uint256 lpNativeBalanceIncreaseInWei
 ) external view returns (uint256 priceRateChange);

 /** @notice configures the rev limiter
 * @param settings settings struct of the revlimiter
 */
 function configure(RevSettings memory settings) external;

 /** @notice retrieves the rev limiter settings
 * @param settings settings struct of the revlimiter
 */
 function revSettings() external view returns (RevSettings memory settings);
}
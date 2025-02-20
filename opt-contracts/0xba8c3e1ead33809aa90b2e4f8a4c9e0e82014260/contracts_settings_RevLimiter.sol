// @author Daosourced
// @date October 06, 2023
pragma solidity ^0.8.12;

import './openzeppelin_contracts_token_ERC20_IERC20.sol';
import './openzeppelin_contracts_token_ERC20_ERC20.sol';
import "./openzeppelin_contracts_utils_math_Math.sol";
import "./openzeppelin_contracts-upgradeable_utils_structs_EnumerableMapUpgradeable.sol";
import "./openzeppelin_contracts-upgradeable_utils_structs_EnumerableSetUpgradeable.sol";

import './contracts_utils_Arrays.sol';
import './contracts_utils_Distribution.sol';
import './contracts_liquidity_IExchange.sol';
import './contracts_liquidity_ILiquidityManager.sol';
import './contracts_roles_ProtocolAdminRole.sol';
import './contracts_rewards_IRewardsPool.sol';
import './contracts_settings_DistributionSettings.sol';
import './contracts_settings_IRevLimiter.sol';

/**
* @title This contract is tasked with applying revLimit rules for payment actions
* @notice can be called at distribution controller
*/
contract RevLimiter is ProtocolAdminRole, IRevLimiter {

  using Math for uint256;
  using Distribution for uint256; 
  
  bytes32 private constant REV_ADMIN_ROLE = keccak256('REV_ADMIN_ROLE');
  uint256 private PROTECTED_LP_BALANCE_IN_BPS;
  uint256 private SWAPPABLE_SPACE_SHARE_IN_BPS;
  uint256 private  SAFE_PRICE_CHANGE_RATE_IN_BPS;
  
  ILiquidityManager _lpManager;
  
  function initialize(
      address lpManager,
      uint256 protectedLPBalanceInBps,
      uint256 safePriceRateChangeInBps,
      uint256 swappableSpaceShareInBps
    ) initializer public {
      __ProtocolAdminRole_init();
      __RevLimiter_init(
        lpManager,
        protectedLPBalanceInBps,
        safePriceRateChangeInBps,
        swappableSpaceShareInBps
    );
  }
    
  function __RevLimiter_init(
    address lpManager,
    uint256 protectedLPBalanceInBps,
    uint256 safePriceRateChangeInBps,
    uint256 swappableSpaceShareInBps
  ) internal onlyInitializing {
    _setRoleAdmin(REV_ADMIN_ROLE, PROTOCOL_ADMIN_ROLE);
    _lpManager = ILiquidityManager(lpManager);
    PROTECTED_LP_BALANCE_IN_BPS = protectedLPBalanceInBps;
    SAFE_PRICE_CHANGE_RATE_IN_BPS = safePriceRateChangeInBps;
    SWAPPABLE_SPACE_SHARE_IN_BPS = swappableSpaceShareInBps;
  }

  function calculateMintableAndSwappableLiquidity(
    uint256 shareOfLiquidityPoolInWei, 
    uint256 gasSentWithTransaction
  ) public view override returns (
    uint256 tokenMintAmountInWei, 
    uint256 tokenSwapAmountInWei,
    uint256 minEthSwapAmountInWei,
    uint256 ethLeftOverAfterSwapInWei
  ) {

    IExchange lp = IExchange(_lpManager.getHLiquidityPool().proxyAddress);
    ERC20 token = ERC20(_lpManager.getHLiquidityPool().token);

    uint256 priceRateChange = _calculatePriceDecreaseRateForLiquidity(
      token,
      shareOfLiquidityPoolInWei, 
      gasSentWithTransaction
    );
    uint256 lpBalance = _lpManager.getHLiquidityPool().tokenBalance;
    if(priceRateChange >= SAFE_PRICE_CHANGE_RATE_IN_BPS) {
      uint256 maxSpaceReservedForSwap = (lpBalance.calculateShare(10000 - 
      PROTECTED_LP_BALANCE_IN_BPS)).calculateShare(SWAPPABLE_SPACE_SHARE_IN_BPS);
      ( 
        minEthSwapAmountInWei, 
        ethLeftOverAfterSwapInWei, 
        tokenSwapAmountInWei,
        tokenMintAmountInWei
      ) = _calculateEthRequiredForSwap(lp, gasSentWithTransaction, maxSpaceReservedForSwap);
    }
  }

  function _calculateEthRequiredForSwap(
    IExchange lp,
    uint256 ethAmountInWei,
    uint256 tokenSwapAmountInWei
  ) internal view returns (
    uint256 minEthRequiredForSwapInWei, 
    uint256 leftOverEthAfterSwapInWei, 
    uint256 swappableSpaceAmountInWei, 
    uint256 spaceLeftOverForMint
  ) {
    minEthRequiredForSwapInWei = lp.getEthToTokenOutputPrice(tokenSwapAmountInWei);
    if(minEthRequiredForSwapInWei <= ethAmountInWei) {
      leftOverEthAfterSwapInWei = ethAmountInWei - minEthRequiredForSwapInWei;
      swappableSpaceAmountInWei = tokenSwapAmountInWei;
      spaceLeftOverForMint = 0;
    } else {    
      leftOverEthAfterSwapInWei = 0;
      swappableSpaceAmountInWei = lp.getEthToTokenInputPrice(ethAmountInWei);
      spaceLeftOverForMint = tokenSwapAmountInWei >= swappableSpaceAmountInWei ?  tokenSwapAmountInWei - swappableSpaceAmountInWei : 0;
      minEthRequiredForSwapInWei = ethAmountInWei;
    }
  }
  
  function calculatePriceDecreaseRateForLiquidity(
      uint256 lpTokenBalanceIncreaseInWei,
      uint256 lpNativeBalanceIncreaseInWei
    ) public view override returns (uint256 priceRateChange) {
      priceRateChange = _calculatePriceDecreaseRateForLiquidity(
        ERC20(_lpManager.getHLiquidityPool().token),
        lpTokenBalanceIncreaseInWei,
        lpNativeBalanceIncreaseInWei
      );
  }

  function _calculatePriceDecreaseRateForLiquidity(
      ERC20 token,
      uint256 lpTokenBalanceIncreaseInWei,
      uint256 lpNativeBalanceIncreaseInWei
    ) internal view returns (uint256 priceRateChange) {
      uint256 nativeReserve = _lpManager.getHLiquidityPool().balance;
      uint256 tokenReserve = _lpManager.getHLiquidityPool().tokenBalance;
      uint256 outputAmount = 1*10**token.decimals();
      uint256 currentEthPerSpaceInWei = _calculateEthToTokenOutputPrice(
        outputAmount,
        nativeReserve,
        tokenReserve
      );
      uint256 projectedEthPerSpaceInWei = _calculateEthToTokenOutputPrice(
        outputAmount,
        nativeReserve + lpNativeBalanceIncreaseInWei,
        tokenReserve + lpTokenBalanceIncreaseInWei
      );
      uint256 tokenPriceDeltaInEth;
      if(currentEthPerSpaceInWei > projectedEthPerSpaceInWei) {
        tokenPriceDeltaInEth = currentEthPerSpaceInWei - projectedEthPerSpaceInWei;
        priceRateChange = tokenPriceDeltaInEth.mulDiv(10000, currentEthPerSpaceInWei);
      }  else {
        priceRateChange = 0;
      }
  }

  function configure(
    RevSettings memory settings
  ) external override onlyProtocolAdmin {
    SAFE_PRICE_CHANGE_RATE_IN_BPS = settings.safePriceRateChangeInBps;
    PROTECTED_LP_BALANCE_IN_BPS = settings.protectedLPBalanceInBps;
    SWAPPABLE_SPACE_SHARE_IN_BPS = settings.swappableSpaceShareInBps;
    emit RevLimiterConfiguration(SAFE_PRICE_CHANGE_RATE_IN_BPS, PROTECTED_LP_BALANCE_IN_BPS, SWAPPABLE_SPACE_SHARE_IN_BPS);
  }

  function revSettings() external view override returns (RevSettings memory settings) {
    return RevSettings({
      protectedLPBalanceInBps: PROTECTED_LP_BALANCE_IN_BPS,
      safePriceRateChangeInBps: SAFE_PRICE_CHANGE_RATE_IN_BPS,
      swappableSpaceShareInBps: SWAPPABLE_SPACE_SHARE_IN_BPS
    });
  }
  
  function _calculateEthToTokenOutputPrice(
    uint256 outputAmount,
    uint256 inputReserve,
    uint256 outputReserve
  ) internal pure returns (uint256) {
    uint256 denominator = outputReserve - outputAmount;
    return inputReserve.mulDiv(outputAmount, denominator);
  }
  uint256[50] private __gap;
}
// SPDX-License-Identifier: None
pragma solidity ^0.8.18;

import {VanillaOptionPool} from "./contracts_libraries_combo-pools_VanillaOptionPool.sol";
import {LPPosition} from "./contracts_libraries_LPPosition.sol";

import {TickMath} from "./contracts_libraries_TickMath.sol";
import {LiquidityRouterUtils} from "./contracts_libraries_LiquidityRouterUtils.sol";
import {AlcorUniswapExchange} from "./contracts_libraries_combo-pools_AlcorUniswapExchange.sol";

import {IVALM} from "./contracts_interfaces_IVALM.sol";
import {IV3Pool} from "./contracts_interfaces_v3-pool_IV3Pool.sol";
import {IOptionLiquidityRouter} from  "./contracts_interfaces_IOptionLiquidityRouter.sol";

contract OptionLiquidityRouter is IOptionLiquidityRouter{
    using VanillaOptionPool for VanillaOptionPool.Key;

    IV3Pool public immutable v3Pool;    
    IVALM public immutable VALM;
    address public immutable token;
    address public protocolOwner;

    uint256 minAmountForMint;
    int24 poolTickSpacing;  

    bool unlocked;

    constructor(
        address _V3Pool,
        address _VALM
    ){
        v3Pool = IV3Pool(_V3Pool);
        VALM = IVALM(_VALM);

        token = v3Pool.token();
        protocolOwner = VALM.protocolOwner();
        minAmountForMint = VALM.minAmountForMint();
        poolTickSpacing = v3Pool.tickSpacing();
        unlocked = true;
    }
     
    modifier lock() {
        if (!unlocked) revert LOK();
        unlocked = false;
        _;
        unlocked = true;
    }

    function mintAcrossCallPools(
        BatchMintInfo memory mintInfo, 
        uint256 amount,         
        AlcorUniswapExchange.SwapParams memory swapParams
    ) external lock returns(uint256 amountToTransfer0, uint256 amountToTransfer1, LPPosition.Key[] memory , uint128[] memory)
    {
        if(msg.sender != mintInfo.owner) revert notOwner();
        if(!LiquidityRouterUtils.checkTicksPercents(mintInfo.tickLowerPercent, mintInfo.tickUpperPercent)) revert IncorrectPercentValue();
        
        (bytes32[] memory outOfMoneyPoolHashes, uint256[] memory outOfMoneyStrikes) = getOutOfMoneyPools(mintInfo.expiry, true);
        LPPosition.Key[] memory lpPositionKeys = new LPPosition.Key[](outOfMoneyStrikes.length);
        uint128[] memory amounts = new uint128[](outOfMoneyStrikes.length);

        for(uint128 i = 0; i < outOfMoneyPoolHashes.length; i++){
            (lpPositionKeys[i], amounts[i]) = createPositionKeyAndAmount(mintInfo, outOfMoneyPoolHashes[i], outOfMoneyStrikes[i], amount/outOfMoneyPoolHashes.length);
        }
        (amountToTransfer0, amountToTransfer1) = VALM.mint(lpPositionKeys, amounts, swapParams);

        return(amountToTransfer0, amountToTransfer1, lpPositionKeys, amounts);   
    }

    function getOutOfMoneyPools(uint256 expiry, bool isCall) public view returns (bytes32[] memory, uint256[] memory) {
        uint256 currentAssetPrice = v3Pool.getCurrentOptionPrice();
        uint256[] memory availableStrikes = v3Pool.getAvailableStrikes(expiry, isCall);
        
        uint256 outOfMoneyCount = 0;
        for (uint256 i = 0; i < availableStrikes.length; i++){
            if (availableStrikes[i] > currentAssetPrice) {
                outOfMoneyCount++;
            }
        }
        uint256[] memory outOfMoneyStrikes = new uint256[](outOfMoneyCount);
        bytes32[] memory poolHashes = new bytes32[](outOfMoneyCount);
        uint256 index = 0;

        for (uint256 i = 0; i < availableStrikes.length; i++) {
            if (availableStrikes[i] > currentAssetPrice) {
                poolHashes[index] = VanillaOptionPool.Key({
                    expiry: expiry, 
                    strike: availableStrikes[i], 
                    isCall: isCall
                }).hashOptionPool();
                outOfMoneyStrikes[index] = availableStrikes[i];
                index++;
            }
        }
        
        return (poolHashes, outOfMoneyStrikes);
    }

    
    function createPositionKeyAndAmount(
        BatchMintInfo memory mintInfo,
        bytes32 poolHash,
        uint256 strike,
        uint256 amountToMint 
    ) internal view returns (LPPosition.Key memory lpKey, uint128 liquidity) {
        (uint160 sqrtPriceX96, ,) = v3Pool.slots0(poolHash);
        int24 tickLower = LiquidityRouterUtils.calculateAdjustedTick(sqrtPriceX96, mintInfo.tickLowerPercent, poolTickSpacing);
        int24 tickUpper = LiquidityRouterUtils.calculateAdjustedTick(sqrtPriceX96, mintInfo.tickUpperPercent, poolTickSpacing);
        
        lpKey = LPPosition.Key({
            owner: mintInfo.owner,
            expiry: mintInfo.expiry,
            strike: strike,
            isCall: true,
            tickLower: tickLower,
            tickUpper: tickUpper
        });
        
        (liquidity, amountToMint) = LiquidityRouterUtils.calculateLiquidityAmount(
            TickMath.getSqrtRatioAtTick(tickLower),
            TickMath.getSqrtRatioAtTick(tickUpper),
            sqrtPriceX96,
            amountToMint
        );
        if(amountToMint < minAmountForMint) revert notEnoughAmountForMint();
    }

    struct OptionPoolInfoView {
        uint256 expiry;
        uint256 strike;
        bool isCall;
        uint256 sqrtPriceX96;
        uint256 amount0Balance;
        uint256 amount1Balance;
    }

    // used by front-end
    function getOptionPoolsInfoForExpiry(
        uint256 expiry,
        bool isCall
    ) external view returns (OptionPoolInfoView[] memory) {
        uint256[] memory strikes = v3Pool.getAvailableStrikes(expiry, isCall);

        OptionPoolInfoView[] memory optionPoolsInfos = new OptionPoolInfoView[](
            strikes.length
        );

        bytes32 optionPoolKeyHash;
        uint160 sqrtPriceX96;
        for (uint16 i = 0; i < strikes.length; i++) {
            optionPoolKeyHash = VanillaOptionPool
                .Key({expiry: expiry, strike: strikes[i], isCall: isCall})
                .hashOptionPool();
            (sqrtPriceX96, , ) = v3Pool.slots0(optionPoolKeyHash);
            (uint256 amount0Balance, uint256 amount1Balance) = v3Pool
                .poolsBalances(optionPoolKeyHash);
            optionPoolsInfos[i] = OptionPoolInfoView({
                expiry: expiry,
                strike: strikes[i],
                isCall: isCall,
                sqrtPriceX96: sqrtPriceX96,
                amount0Balance: amount0Balance,
                amount1Balance: amount1Balance
            });
        }
        return optionPoolsInfos;
    }

}
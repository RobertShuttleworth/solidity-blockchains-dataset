// SPDX-License-Identifier: None
pragma solidity ^0.8.18;

import {AlcorOptionVaultCore} from "./contracts_alcor_AlcorOptionVaultCore.sol";
import {BaseComboOption} from "./contracts_alcor_combo_BaseComboOption.sol";

import {VanillaOptionPool} from "./contracts_libraries_combo-pools_VanillaOptionPool.sol";
import {LPPosition} from "./contracts_libraries_LPPosition.sol";
import {OptionBalanceMath} from "./contracts_libraries_OptionBalanceMath.sol";
import {FullMath} from "./contracts_libraries_FullMath.sol";

import {SafeMath} from "./contracts_libraries_SafeMath.sol";
import {TickMath} from "./contracts_libraries_TickMath.sol";
import {SimpleMath} from "./contracts_libraries_SimpleMath.sol";
import {AlcorUniswapExchange} from "./contracts_libraries_combo-pools_AlcorUniswapExchange.sol";

import {SafeERC20} from "./openzeppelin_contracts_token_ERC20_utils_SafeERC20.sol";
import {ERC20} from "./openzeppelin_contracts_token_ERC20_ERC20.sol";

import {IVALM} from "./contracts_interfaces_IVALM.sol";
import {IV3PoolActions} from "./contracts_interfaces_v3-pool_IV3PoolActions.sol";

contract VALM is AlcorOptionVaultCore, BaseComboOption, IVALM {
    using FullMath for uint256;
    using SafeERC20 for ERC20;
    using LPPosition for LPPosition.Key;
    using VanillaOptionPool for VanillaOptionPool.Key;
    using OptionBalanceMath for mapping(address owner => mapping(bytes32 optionPoolKeyHash => int256));
    using LPPosition for mapping(bytes32 => LPPosition.Info);
    bool private constant OPTION_TYPE_CALL = true;

    constructor(
        address _V3Pool,
        address _uniswapRouter, 
        string memory _comboOptionName,
        uint256 _minAmountForMint,
        uint128 _minLiquidationAmount, 
        uint256 _liquidationFeeShare
    )
        BaseComboOption(_comboOptionName, OPTION_TYPE_CALL)
        AlcorOptionVaultCore(
            _V3Pool,
            _uniswapRouter,
            msg.sender,
            _minAmountForMint,
            _minLiquidationAmount,
            _liquidationFeeShare
        )
    {}

    function mint(
        LPPosition.Key[] memory lpPositionKeys, 
        uint128[] memory amounts, 
        AlcorUniswapExchange.SwapParams memory swapParams
    ) external lock nonEmptyArray(lpPositionKeys.length) returns (uint256 amountToTransfer0, uint256 amountToTransfer1) {
        address firstPositionOwner = lpPositionKeys[0].owner; 

        for(uint128 i = 0; i < lpPositionKeys.length; i++){
            LPPosition.Key memory lpPositionKey = lpPositionKeys[i];
            
            checkOptionType(lpPositionKey.isCall);
            if (msg.sender != lpPositionKey.owner  &&  !v3Pool.approvedManager(msg.sender)) revert notOwner();
            
            if (lpPositionKey.owner != firstPositionOwner) revert ownersMismatch();
    
            (uint256 amount0Delta, uint256 amount1Delta) = _mintLP(lpPositionKey, amounts[i]);
            if ((amount0Delta + amount1Delta) < minAmountForMint) revert notEnoughAmountForMint();

            amountToTransfer0 += amount0Delta;
            amountToTransfer1 += amount1Delta;
        }

        if(amountToTransfer0 + amountToTransfer1 > 0){
            if(swapParams.token == token){
                ERC20(token).safeTransferFrom(
                    firstPositionOwner,
                    address(v3Pool),
                    amountToTransfer0 + amountToTransfer1
                );
            }
            else{
                AlcorUniswapExchange.swapTokensThroughUniswap(firstPositionOwner, uniswapRouter, v3Pool, token, -int256(amountToTransfer0 + amountToTransfer1), swapParams);
            }
        }
    }

    function burn(
        LPPosition.Key[] memory lpPositionKeys,
        AlcorUniswapExchange.SwapParams memory swapParams
    )
    external
    lock
    nonEmptyArray(lpPositionKeys.length)
    returns (uint256 amount0ToTransfer, uint256 amount1ToTransfer)
    {
    address firstPositionOwner = lpPositionKeys[0].owner; 
    for (uint128 i = 0; i < lpPositionKeys.length; i++) {
        LPPosition.Key memory lpPositionKey = lpPositionKeys[i];

        checkOptionType(lpPositionKey.isCall);

        if (msg.sender != lpPositionKey.owner && !v3Pool.approvedManager(msg.sender)) {
            revert notOwner();
        }

        if (lpPositionKey.owner != firstPositionOwner) revert ownersMismatch();

        (uint256 amount0ToTransferDelta, uint256 amount1ToTransferDelta) = _burnLP(
            usersBalances,
            lpPositionKey,
            false
        );

        amount0ToTransfer += amount0ToTransferDelta;
        amount1ToTransfer += amount1ToTransferDelta;
    }

    if (amount0ToTransfer + amount1ToTransfer > 0) {
        if (swapParams.token == token) {
            v3Pool.transferFromPool(
                token,
                firstPositionOwner,
                amount0ToTransfer + amount1ToTransfer
            );
        } else {
            AlcorUniswapExchange.swapTokensThroughUniswap(
                firstPositionOwner,
                uniswapRouter,
                v3Pool,
                token,
                int256(amount0ToTransfer + amount1ToTransfer),
                swapParams
            );
        }
    }
    }

    
    // @dev this function allows to collect the spread fees accrued by user's LP position
    // @dev we don't need whenNotExpired modifier here as user should be able to collect fees at any time
    function collectFees(
        LPPosition.Key[] memory lpPositionKeys, 
        AlcorUniswapExchange.SwapParams memory swapParams
    ) external lock nonEmptyArray(lpPositionKeys.length) returns (uint128 amount) {
        for(uint128 i = 0; i < lpPositionKeys.length; i++){
            LPPosition.Key memory lpPositionKey = lpPositionKeys[i];

            checkOptionType(lpPositionKey.isCall);
            if (msg.sender != lpPositionKey.owner) revert notOwner();

            amount += _collectFeesLP(lpPositionKey);
        }
        if(swapParams.token == token){
            v3Pool.transferFromPool(token, lpPositionKeys[0].owner, amount);
        }
        else{
            AlcorUniswapExchange.swapTokensThroughUniswap(lpPositionKeys[0].owner, uniswapRouter, v3Pool, token, int256(uint256(amount)), swapParams);
        }
    }

    function swap(
        VanillaOptionPool.Key memory optionPoolKey,
        bool zeroForOne,
        int256 amountSpecified,
        uint160 sqrtPriceLimitX96,
        AlcorUniswapExchange.SwapParams memory swapParams
    )
        external
        lock
        returns (
            int256 amount0PoolShouldTransfer,
            int256 amount1PoolShouldTransfer
        )
    {
        checkOptionType(optionPoolKey.isCall);

        if (
            !((zeroForOne && amountSpecified < 0) ||
                (!zeroForOne && amountSpecified > 0))
        ) revert incorrectDirections();

        address owner = msg.sender;

        // swap
        (int256 amount0, int256 amount1, uint256 additionalFee) = v3Pool.swap(
            IV3PoolActions.SwapInputs({
                optionPoolKeyHash: optionPoolKey.hashOptionPool(),
                zeroForOne: zeroForOne,
                amountSpecified: amountSpecified,
                sqrtPriceLimitX96: sqrtPriceLimitX96
            })
        );

        if (amount1 != amountSpecified || amount0 == 0)
            revert SpecifiedAndReturnedAmountNotRelated();

        if (!zeroForOne) {
            amountSpecified -= int256(additionalFee);
        }

        int256 userOptionBalance = usersBalances.getOptionBalance(
            owner,
            optionPoolKey.hashOptionPool()
        );

        (
            amount0PoolShouldTransfer,
            amount1PoolShouldTransfer
        ) = OptionBalanceMath.calculateNewOptionBalance(
            userOptionBalance,
            amount0,
            amountSpecified
        );

        if(!zeroForOne){
            amount1PoolShouldTransfer -= int256(additionalFee);
        }

       if (swapParams.token == token) {
            int256 totalAmountPoolShouldTransfer = amount0PoolShouldTransfer+amount1PoolShouldTransfer;
            if (totalAmountPoolShouldTransfer < 0) {
                ERC20(token).safeTransferFrom(
                    owner,
                    address(v3Pool),
                    uint256(-(totalAmountPoolShouldTransfer))
                );
            } else {
                v3Pool.transferFromPool(
                    token,
                    owner,
                    uint256(totalAmountPoolShouldTransfer)
                );
            }
        } else {
            if (amount1PoolShouldTransfer < 0) {
                ERC20(token).safeTransferFrom(
                    owner,
                    address(v3Pool),
                    uint256(-amount1PoolShouldTransfer)
            );
            } else {
                v3Pool.transferFromPool(
                    token,
                    owner,
                    uint256(amount1PoolShouldTransfer)
                );
            }
            AlcorUniswapExchange.swapTokensThroughUniswap(owner, uniswapRouter, v3Pool, token, amount0PoolShouldTransfer, swapParams);
        }

        // update user's option balance
        usersBalances.updateOptionBalance(
            owner,
            optionPoolKey.hashOptionPool(),
            -amountSpecified
        );

        v3Pool.updatePoolBalances(
            optionPoolKey.hashOptionPool(),
            -int256(amount0PoolShouldTransfer),
            -int256(amount1PoolShouldTransfer)
        );

        emit AlcorSwap(
            owner,
            amount0,
            amountSpecified, 
            v3Pool.getCurrentOptionPrice()
        );
    }

    // @dev this function allows to either exercise a call option or withdraw a collateral
    function withdraw(
        VanillaOptionPool.Key[] memory optionPoolKeys, 
        AlcorUniswapExchange.SwapParams memory swapParams
    ) external lock returns (uint256 amount) {
        address owner = msg.sender;
        for(uint128 i = 0; i < optionPoolKeys.length; i++){
            VanillaOptionPool.Key memory optionPoolKey = optionPoolKeys[i];
            checkOptionType(optionPoolKey.isCall);
            amount += _withdraw(usersBalances, optionPoolKey, owner);
        }
        if(amount > 0){
            if(swapParams.token == token){
                // do transfers
                v3Pool.transferFromPool(token, owner, amount);
            }
            else{
                AlcorUniswapExchange.swapTokensThroughUniswap(owner, uniswapRouter, v3Pool, token, int256(amount), swapParams);
            }
        }
    }

    function updateLPPositons(
        LPPosition.Key[] memory lpPositionKeys,
        VanillaOptionPool.Key memory newOptionPoolKey,
        bool isUnlocked
    ) external onlyApprovedManager lock returns(uint128 protocolFee, uint256 isUpdatedBitMap){
        bytes32 newOptionPoolHash = newOptionPoolKey.hashOptionPool();
        v3Pool.validatePoolExists(newOptionPoolHash);
        v3Pool.setLockedPool(newOptionPoolHash, true);
        for (uint256 i = 0; i < lpPositionKeys.length; i++) {
            LPPosition.Key memory lpPositionKey = lpPositionKeys[i];
            if (block.timestamp > lpPositionKey.expiry) {
                checkOptionType(lpPositionKey.isCall);
                    uint128 liquidationFee;
                    uint128 positionOwedBefore;
                    uint128 positionOwedAfter;

                    positionOwedBefore 
                        = v3Pool.getLPPositionTokenOwed(
                        lpPositionKey.hashOptionPool(),
                        lpPositionKey.owner,
                        lpPositionKey.tickLower,
                        lpPositionKey.tickUpper
                    );

                    if(_updateLPPosition(
                        usersBalances,
                        lpPositionKey,
                        newOptionPoolKey
                    )){
                        isUpdatedBitMap |= (1 << i);
                    }
                    
                    positionOwedAfter 
                        = v3Pool.getLPPositionTokenOwed(
                        lpPositionKey.hashOptionPool(),
                        lpPositionKey.owner,
                        lpPositionKey.tickLower,
                        lpPositionKey.tickUpper
                    );  

                    if (
                       positionOwedAfter > positionOwedBefore
                    ) {
                        liquidationFee = uint128(
                            FullMath.mulDivRoundingUp(
                                positionOwedAfter - positionOwedBefore,
                                liquidationFeeShare,
                                1e6 - liquidationFeeShare
                            )
                        );

                        if(liquidationFee < minLiquidationAmount){
                            liquidationFee = uint128(SimpleMath.min(uint256(minLiquidationAmount), uint256(positionOwedAfter-positionOwedBefore)));
                        }

                        v3Pool.collect(
                            lpPositionKey.owner,
                            lpPositionKey.hashOptionPool(),
                            lpPositionKey.tickLower,
                            lpPositionKey.tickUpper,
                            liquidationFee
                        );
                        protocolFee += liquidationFee;
                    }
            }
        }
        v3Pool.updateProtocolFees(protocolFee);
        v3Pool.setLockedPool(newOptionPoolHash, isUnlocked);
    } 
}
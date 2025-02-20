// SPDX-License-Identifier: None
pragma solidity ^0.8.18;

import {FullMath} from "./contracts_libraries_FullMath.sol";
import {TickMath} from "./contracts_libraries_TickMath.sol";

import {SafeERC20} from "./openzeppelin_contracts_token_ERC20_utils_SafeERC20.sol";
import {ERC20} from "./openzeppelin_contracts_token_ERC20_ERC20.sol";

import {BaseComboOption} from "./contracts_alcor_combo_BaseComboOption.sol";
import {OptionBalanceMath} from "./contracts_libraries_OptionBalanceMath.sol";
import {OptionSpreadPool} from "./contracts_libraries_combo-pools_OptionSpreadPool.sol";
import {VanillaOptionPool} from "./contracts_libraries_combo-pools_VanillaOptionPool.sol";
import {AlcorUniswapExchange} from "./contracts_libraries_combo-pools_AlcorUniswapExchange.sol";

import {ISwapRouter} from "./contracts_interfaces_ISwapRouter.sol";
import {IV3Pool} from "./contracts_interfaces_v3-pool_IV3Pool.sol";
import {IV3PoolActions} from "./contracts_interfaces_v3-pool_IV3PoolActions.sol";

import {IBaseComboOption} from "./contracts_interfaces_IBaseComboOption.sol";
contract OptionCallSpread is BaseComboOption {
    using FullMath for uint256;
    using SafeERC20 for ERC20;
    using VanillaOptionPool for VanillaOptionPool.Key;
    using OptionSpreadPool for OptionSpreadPool.Key;
    using OptionBalanceMath for mapping(address owner => mapping(bytes32 comboOptionPoolKeyHash => int256));

    error incorrentStrikes();
    error differentAmounts();


    event AlcorSwapSpread(
        address indexed owner,
        int256 amount0,
        int256 amount1, 
        uint256 additionalFee
    );

    event AlcorWithdrawSpread(
        // address indexed owner,
        // uint256 expiry,
        // uint256 strike1,
        // uint256 strike2,
        // bool isCall,
        uint256 amount
    );

    address public immutable token;
    IV3Pool public immutable v3Pool;
    ISwapRouter public immutable uniswapRouter; 
    bool private constant OPTION_TYPE_CALL = true;

    constructor(
        address _V3Pool,
        address _uniswapRouter, 
        string memory _comboOptionName
    ) BaseComboOption(_comboOptionName, OPTION_TYPE_CALL) {
        v3Pool = IV3Pool(_V3Pool);
        token = v3Pool.token();

        uniswapRouter = ISwapRouter(_uniswapRouter);
    }

    struct OptionSpreadUnit {
        uint256 expiry;
        uint256 strikeLow;
        uint256 strikeHigh;
        bool isCall;
        int256 userBalance;
        uint160 sqrtPrice1X96;
        uint160 sqrtPrice2X96;
    }

    struct HelpfulStructForUserPos {
        bytes32 optionSpreadPoolKeyHash;
        bytes32 optionPoolKey1Hash;
        bytes32 optionPoolKey2Hash;
    }

    function getUserPositions(
        address owner,
        uint256 expiry
    ) external view returns (OptionSpreadUnit[] memory) {
        uint256[] memory strikes = v3Pool.getAvailableStrikes(
            expiry,
            optionsTypeIsCall
        );

        OptionSpreadUnit[] memory optionPoolsInfos = new OptionSpreadUnit[](
            strikes.length ** 2
        );

        HelpfulStructForUserPos memory helpfulStruct = HelpfulStructForUserPos({
            optionSpreadPoolKeyHash: bytes32(0),
            optionPoolKey1Hash: bytes32(0),
            optionPoolKey2Hash: bytes32(0)
        });
        uint160 sqrtPrice1X96;
        uint160 sqrtPrice2X96;
        uint32 counter;
        for (uint16 i = 0; i < strikes.length; i++) {
            for (uint16 j = 0; j < strikes.length; j++) {
                if (strikes[i] >= strikes[j]) continue;

                helpfulStruct.optionPoolKey1Hash = VanillaOptionPool
                    .Key({
                        expiry: expiry,
                        strike: strikes[i],
                        isCall: optionsTypeIsCall
                    })
                    .hashOptionPool();
                helpfulStruct.optionPoolKey2Hash = VanillaOptionPool
                    .Key({
                        expiry: expiry,
                        strike: strikes[j],
                        isCall: optionsTypeIsCall
                    })
                    .hashOptionPool();
                (sqrtPrice1X96, , ) = v3Pool.slots0(
                    helpfulStruct.optionPoolKey1Hash
                );
                (sqrtPrice2X96, , ) = v3Pool.slots0(
                    helpfulStruct.optionPoolKey2Hash
                );

                helpfulStruct.optionSpreadPoolKeyHash = OptionSpreadPool
                    .Key({
                        expiry: expiry,
                        strikeLow: strikes[i],
                        strikeHigh: strikes[j],
                        isCall: optionsTypeIsCall
                    })
                    .hashOptionSpreadKey();

                optionPoolsInfos[counter] = OptionSpreadUnit({
                    expiry: expiry,
                    strikeLow: strikes[i],
                    strikeHigh: strikes[j],
                    isCall: optionsTypeIsCall,
                    userBalance: usersBalances[owner][
                        helpfulStruct.optionSpreadPoolKeyHash
                    ],
                    sqrtPrice1X96: sqrtPrice1X96,
                    sqrtPrice2X96: sqrtPrice2X96
                });

                counter++;
            }
        }
        return optionPoolsInfos;
    }

    struct SpreadSwapCache {
        int256 swapFirstAmount0;
        int256 swapFirstAmount1;
        int256 swapSecondAmount0;
        int256 swapSecondAmount1;
    }

    struct SqrtPriceLimits {
        uint160 sqrtPriceLimitLowX96;
        uint160 sqrtPriceLimitHighX96;
    }

    function swap(
        OptionSpreadPool.Key memory optionSpreadPoolKey,
        bool zeroForOne,
        int256 amountSpecified,
        SqrtPriceLimits memory sqrtPriceLimits,
        AlcorUniswapExchange.SwapParams memory swapParams
    )
        external
        lock
        returns (
            int256 amount0PoolShouldTransfer,
            int256 amount1PoolShouldTransfer
        )
    {
        checkOptionType(optionSpreadPoolKey.isCall);
        if (optionSpreadPoolKey.strikeLow >= optionSpreadPoolKey.strikeHigh)
            revert incorrentStrikes();

        if (
            !((zeroForOne && amountSpecified < 0) ||
                (!zeroForOne && amountSpecified > 0))
        ) revert incorrectDirections();
        
        SpreadSwapCache memory spreadSwapCache;

        uint256 additionalFee;

        // swap1 - sell option
        (
            spreadSwapCache.swapFirstAmount0,
            spreadSwapCache.swapFirstAmount1,
            additionalFee
        ) = v3Pool.swap(
            IV3PoolActions.SwapInputs({
                optionPoolKeyHash: VanillaOptionPool
                    .Key({
                        expiry: optionSpreadPoolKey.expiry,
                        strike: zeroForOne ? optionSpreadPoolKey.strikeHigh : optionSpreadPoolKey.strikeLow,
                        isCall: optionSpreadPoolKey.isCall
                    })
                    .hashOptionPool(),
                zeroForOne: false,
                amountSpecified: zeroForOne ? -amountSpecified : amountSpecified, // > 0 
                sqrtPriceLimitX96: zeroForOne ? sqrtPriceLimits.sqrtPriceLimitHighX96 : sqrtPriceLimits.sqrtPriceLimitLowX96
            })
        );
        if (
            spreadSwapCache.swapFirstAmount1 != (zeroForOne ? -amountSpecified : amountSpecified) || spreadSwapCache.swapFirstAmount0 == 0
        ) revert SpecifiedAndReturnedAmountNotRelated();

        zeroForOne ? amountSpecified += int256(additionalFee) :  amountSpecified -= int256(additionalFee);

        // swap2 - buy option
        (
            spreadSwapCache.swapSecondAmount0,
            spreadSwapCache.swapSecondAmount1,
        ) = v3Pool.swap(
            IV3PoolActions.SwapInputs({
                optionPoolKeyHash: VanillaOptionPool
                    .Key({
                        expiry: optionSpreadPoolKey.expiry,
                        strike: !zeroForOne ? optionSpreadPoolKey.strikeHigh : optionSpreadPoolKey.strikeLow,
                        isCall: optionSpreadPoolKey.isCall
                    })
                    .hashOptionPool(),
                zeroForOne: true, 
                amountSpecified: !zeroForOne ? -amountSpecified : amountSpecified, // < 0 
                sqrtPriceLimitX96: !zeroForOne ? sqrtPriceLimits.sqrtPriceLimitHighX96 : sqrtPriceLimits.sqrtPriceLimitLowX96
            })
        );
        if (
            spreadSwapCache.swapSecondAmount1 != (!zeroForOne ? -amountSpecified : amountSpecified) || spreadSwapCache.swapSecondAmount0 == 0
        ) revert SpecifiedAndReturnedAmountNotRelated();
     
        (
            amount0PoolShouldTransfer,
            amount1PoolShouldTransfer
        ) = OptionBalanceMath.calculateNewOptionBalance(
            usersBalances.getOptionBalance(
                msg.sender,
                optionSpreadPoolKey.hashOptionSpreadKey()
            ),
            // addition because V3pool returns signed amounts
            spreadSwapCache.swapFirstAmount0 + spreadSwapCache.swapSecondAmount0,
            amountSpecified
        );
 
        uint256 collateralMultiplier = (optionSpreadPoolKey.strikeHigh -
            optionSpreadPoolKey.strikeLow).mulDiv(
                1e18,
                optionSpreadPoolKey.strikeHigh
            );

        if (amount1PoolShouldTransfer < 0) {
            amount1PoolShouldTransfer = -int256(
                uint256(-amount1PoolShouldTransfer).mulDiv(
                    collateralMultiplier,
                    1e18
                )
            );
        } else if (amount1PoolShouldTransfer > 0) {
            amount1PoolShouldTransfer = int256(
                uint256(amount1PoolShouldTransfer).mulDiv(
                    collateralMultiplier,
                    1e18
                )
            );
        }

        amount1PoolShouldTransfer -= int256(additionalFee); 

        if (swapParams.token == token) {
            int256 totalAmountPoolShouldTransfer = amount0PoolShouldTransfer+amount1PoolShouldTransfer;
            if (totalAmountPoolShouldTransfer < 0) {
                ERC20(token).safeTransferFrom(
                    msg.sender,
                    address(v3Pool),
                    uint256(-(totalAmountPoolShouldTransfer))
                );
            } else {
                v3Pool.transferFromPool(
                    token,
                    msg.sender,
                    uint256(totalAmountPoolShouldTransfer)
                );
            }
        } else {
            if (amount1PoolShouldTransfer < 0) {
                ERC20(token).safeTransferFrom(
                    msg.sender,
                    address(v3Pool),
                    uint256(-amount1PoolShouldTransfer)
            );
            } else {
                v3Pool.transferFromPool(
                    token,
                    msg.sender,
                    uint256(amount1PoolShouldTransfer)
                );
            }
            AlcorUniswapExchange.swapTokensThroughUniswap(msg.sender, uniswapRouter, v3Pool, token, amount0PoolShouldTransfer, swapParams);
        }
      
        // update user's option balance
        usersBalances.updateOptionBalance(
            msg.sender,
            optionSpreadPoolKey.hashOptionSpreadKey(),
            -amountSpecified        
        );

        // should update the v3Pools' balances
        // warning! take account that there should be 2 different "shouldTransfers"

        v3Pool.updatePoolBalances(
            VanillaOptionPool
                .Key({
                    expiry: optionSpreadPoolKey.expiry,
                    strike: optionSpreadPoolKey.strikeLow,
                    isCall: optionSpreadPoolKey.isCall
                })
                .hashOptionPool(),
            zeroForOne ? spreadSwapCache.swapSecondAmount0 : spreadSwapCache.swapFirstAmount0,
            -int256(amount1PoolShouldTransfer) + // ? 
                (zeroForOne ? int256(0) : int256(additionalFee))
        );

        v3Pool.updatePoolBalances(
            VanillaOptionPool
                .Key({
                    expiry: optionSpreadPoolKey.expiry,
                    strike: optionSpreadPoolKey.strikeHigh ,
                    isCall: optionSpreadPoolKey.isCall
                })
                .hashOptionPool(),
            !zeroForOne ? spreadSwapCache.swapSecondAmount0 : spreadSwapCache.swapFirstAmount0,
            int256(amount1PoolShouldTransfer) + // ? 
                (!zeroForOne ? int256(0) : int256(additionalFee))
        );

        emit AlcorSwapSpread(
            msg.sender,
            spreadSwapCache.swapFirstAmount0 + spreadSwapCache.swapSecondAmount0,
            amountSpecified, 
            additionalFee
        );

    }
    function withdraw(
        OptionSpreadPool.Key memory optionSpreadPoolKey
    ) external lock returns (uint256 amount) {
        checkOptionType(optionSpreadPoolKey.isCall);

        address owner = msg.sender;
        int256 userOptionBalance = usersBalances.getOptionBalance(
            owner,
            optionSpreadPoolKey.hashOptionSpreadKey()
        );
        if (userOptionBalance == 0) revert zeroOptionBalance();

        uint256 priceAtExpiry = v3Pool.pricesAtExpiries(
            optionSpreadPoolKey.expiry
        );

        if (priceAtExpiry == 0) revert notExpiredYet();
        
        amount = uint256(
            userOptionBalance > 0 ? userOptionBalance : -userOptionBalance
        ).mulDiv(
                OptionSpreadPool.calculateCallSpreadPayoffInAsset(
                    userOptionBalance > 0,
                    optionSpreadPoolKey.strikeLow,
                    optionSpreadPoolKey.strikeHigh,
                    priceAtExpiry,
                    ERC20(token).decimals()
                ),
                1 ether
            );

        // do transfer
        v3Pool.transferFromPool(token, owner, amount);

        // setting user balance to zero
        usersBalances.updateOptionBalance(
            owner,
            optionSpreadPoolKey.hashOptionSpreadKey(),
            -usersBalances.getOptionBalance(
                owner,
                optionSpreadPoolKey.hashOptionSpreadKey()
            )
        );

        emit AlcorWithdrawSpread(amount);
    }
}
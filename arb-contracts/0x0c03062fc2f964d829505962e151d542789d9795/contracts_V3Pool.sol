// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.18;

import {IV3Pool} from "./contracts_interfaces_v3-pool_IV3Pool.sol";

import {NoDelegateCall} from "./contracts_NoDelegateCall.sol";

import {SafeCast} from "./contracts_libraries_SafeCast.sol";
import {Tick} from "./contracts_libraries_Tick.sol";
import {TickBitmap} from "./contracts_libraries_TickBitmap.sol";
import {Position} from "./contracts_libraries_Position.sol";

import {FullMath} from "./contracts_libraries_FullMath.sol";
import {FixedPoint128} from "./contracts_libraries_FixedPoint128.sol";
import {TransferHelper} from "./contracts_libraries_TransferHelper.sol";
import {TickMath} from "./contracts_libraries_TickMath.sol";
import {SqrtPriceMath} from "./contracts_libraries_SqrtPriceMath.sol";
import {SwapMath} from "./contracts_libraries_SwapMath.sol";
import {V3PoolUtils} from "./contracts_libraries_combo-pools_V3PoolUtils.sol";
import {V3PoolOptions} from "./contracts_V3PoolOptions.sol";

contract V3Pool is IV3Pool, V3PoolOptions, NoDelegateCall {
    using SafeCast for uint256;
    using SafeCast for int256;
    using Tick for mapping(int24 => Tick.Info);
    using TickBitmap for mapping(int16 => uint256);
    using Position for mapping(bytes32 => Position.Info);
    using Position for Position.Info;

    error incorrentToken();

    address public immutable override token;
    uint24 public override fee;
    address public protocolOwner;

    int24 public immutable override tickSpacing;

    uint128 public immutable override maxLiquidityPerTick;

    struct Slot0 {
        // the current price
        uint160 sqrtPriceX96;
        // the current tick
        int24 tick;
        // the most-recently updated index of the observations array
        // uint16 observationIndex;
        // the current maximum number of observations that are being stored
        // uint16 observationCardinality;
        // the next maximum number of observations to store, triggered in observations.write
        // uint16 observationCardinalityNext;
        // the current protocol fee as a percentage of the swap fee taken on withdrawal
        // represented as an integer denominator (1/x)%
        // uint8 feeProtocol;
        // whether the pool is locked
        bool unlocked;
    }
    // Slot0 public override slot0;

    uint8 public feeProtocol;
    uint128 public feeProtocolAmount;

    mapping(bytes32 optionPoolKeyHash => Slot0 _slot0) public override slots0;

    mapping(bytes32 optionPoolKeyHash => uint256 _feeGrowthGlobal0X128) feeGrowthsGlobal0X128;
    mapping(bytes32 optionPoolKeyHash => uint256 _feeGrowthGlobal1X128) feeGrowthsGlobal1X128;

    mapping(bytes32 optionPoolKeyHash => uint128 liquidity) public liquidities;
    mapping(bytes32 optionPoolKeyHash => mapping(int24 => Tick.Info))
        public ticks;
    mapping(bytes32 optionPoolKeyHash => mapping(int16 => uint256))
        public tickBitmap;
    mapping(bytes32 optionPoolKeyHash => mapping(bytes32 => Position.Info))
        public positions;

    // modifiers
    modifier OnlyOwner() {
        require(msg.sender == protocolOwner, "NaW");
        _;
    }

    modifier OnlyComboContract() {
        if (!isApprovedComboContract[msg.sender])
            revert notApprovedComboContract();
        _;
    }

    modifier OnlyPositionManager() {
        if (!approvedManager[msg.sender] && msg.sender != protocolOwner)
            revert notApprovedManager();
        _;
    }

    modifier OnlyComboOrManager() {
        if (!isApprovedComboContract[msg.sender] && !approvedManager[msg.sender] && msg.sender != protocolOwner)
            revert notApprovedManager();
        _;
    }
  
    // @ AlcorFinance
    bool mainlyUnlocked = true;
    /// @dev Mutually exclusive reentrancy protection into the pool to/from a method. This method also prevents entrance
    /// to a function before the pool is initialized. The reentrancy guard is required throughout the contract because
    /// we use balance checks to determine the payment status of interactions such as mint, swap and flash.
    modifier GlobalLock() {
        if (!mainlyUnlocked) revert LOK();
        mainlyUnlocked = false;
        _;
        mainlyUnlocked = true;
    }

    constructor(
        address _token,
        uint24 _fee,
        int24 _tickSpacing,
        address _realUniswapV3PoolAddr,
        address[] memory approvedTokenForPayment, 
        address[] memory approvedPositionsManagers
    ) V3PoolOptions(_realUniswapV3PoolAddr) {
        protocolOwner = msg.sender;
        require(_token != address(0));
        (token, fee, tickSpacing) = (
            _token,
            _fee,
            _tickSpacing
        );
       
        maxLiquidityPerTick = Tick.tickSpacingToMaxLiquidityPerTick(
            _tickSpacing
        );
        managePaymentTokens(approvedTokenForPayment, true);
        managePositionManagers(approvedPositionsManagers, true);
    }

    function checkPositionLiquidity(
        bytes32 optionPoolKeyHash,
        address owner,
        int24 tickLower,
        int24 tickUpper
    ) external view returns (bool) {
        return ((
            positions[optionPoolKeyHashAliases[optionPoolKeyHash]].get(
                owner,
                tickLower,
                tickUpper
            )
        ).liquidity > 0);
    }

    function getLPPositionTokenOwed(
        bytes32 optionPoolKeyHash,
        address owner,
        int24 tickLower,
        int24 tickUpper
    ) external view returns (uint128) {
        Position.Info memory position = positions[
            optionPoolKeyHashAliases[optionPoolKeyHash]
        ].get(owner, tickLower, tickUpper);
        return (position.tokensOwed);
    }

    function toExpiredState(uint256 expiry) external GlobalLock {
        _toExpiredState(expiry);
    }

    function updateLPfees(uint24 _fee) external OnlyOwner {
        // max LP fee is 10%
        require(_fee < 1e5);
        fee = _fee;
    }
    
    function updateMinExpiryInterval(uint256 newMinExpiryInterval) external OnlyOwner { 
        _setMinExpiryInterval(newMinExpiryInterval);
    }

    function setLocked(bool isLocked) external OnlyOwner {
        mainlyUnlocked = isLocked;
    }    

    function addComboOption(address comboOptionAddress) external OnlyOwner {
        _addComboOption(comboOptionAddress);
    }

    function managePositionManagers(
        address[] memory positionManagersAddressesArray, 
        bool isAdd
    ) public OnlyOwner { 
         _manageAddresses(approvedManager, positionManagersAddressesArray, isAdd);
    }

    function managePaymentTokens(
        address[] memory paymentTokensAddressesArray, 
        bool isAdd
    ) public OnlyOwner {
        _manageAddresses(approvedForPayment, paymentTokensAddressesArray, isAdd);
    }

    function setLockedPool(
        bytes32 optionPoolKeyHash,
        bool isLocked
    ) external OnlyComboOrManager {
        slots0[optionPoolKeyHash].unlocked = isLocked;
    }

    function updateProtocolFees(
        uint128 amountDelta
    ) external OnlyComboContract {
        feeProtocolAmount += amountDelta;
    }

    function updatePoolBalances(
        bytes32 optionPoolKeyHash,
        int256 amount0Delta,
        int256 amount1Delta
    ) external OnlyComboContract {
        _updatePoolBalances(optionPoolKeyHash, amount0Delta, amount1Delta);
    }

    function transferFromPool(
        address _token,
        address to,
        uint256 amount
    ) external GlobalLock OnlyComboContract {
        if (_token == token) TransferHelper.safeTransfer(token, to, amount);
        else revert incorrentToken();
    }

    function updatePoolExirationAndStrike(
        bytes32 previousOptionPoolKeyHash,
        uint256 expiry,
        uint256 strike,
        bool isCall,
        bool unlocked
    ) external OnlyPositionManager {
        validatePoolExists(previousOptionPoolKeyHash);
        checkMinExpiryChange(optionPoolKeyStructs[previousOptionPoolKeyHash].expiry, expiry);

        bytes32 newOptionPoolKeyHash = _updatePoolExirationAndStrike(
            optionPoolKeyHashAliases[previousOptionPoolKeyHash],
            expiry,
            strike,
            isCall
        );
        Slot0 memory previousSlot0 = slots0[previousOptionPoolKeyHash];
        previousSlot0.unlocked = unlocked;
        slots0[newOptionPoolKeyHash] = previousSlot0;

        emit UpdatePool(
            previousOptionPoolKeyHash, 
            newOptionPoolKeyHash, 
            slots0[newOptionPoolKeyHash].sqrtPriceX96, 
            slots0[newOptionPoolKeyHash].tick
        );
    }

    /// @dev not locked because it initializes unlocked
    function initialize(
        uint256 expiry,
        uint256 expirationPeriod,
        uint256 strike,
        bool isCall,
        uint160 sqrtPriceX96
    ) external override OnlyPositionManager {
        bytes32 optionPoolKeyHash = _addOptionPool(expiry, strike, isCall);
        Slot0 memory slot0 = slots0[optionPoolKeyHash];
        if (slot0.sqrtPriceX96 != 0) revert AI();
        require(sqrtPriceX96 != 0);

        int24 tick = TickMath.getTickAtSqrtRatio(sqrtPriceX96);

        slot0 = Slot0({
            sqrtPriceX96: sqrtPriceX96,
            tick: tick,
            // observationIndex: 0,
            // observationCardinality: 0, // cardinality,
            // observationCardinalityNext: 0, // cardinalityNext,
            // feeProtocol: 0,
            unlocked: true
        });

        slots0[optionPoolKeyHash] = slot0;

        emit Initialize(
            optionPoolKeyHash,
            expirationPeriod,
            sqrtPriceX96,
            tick
        );
    }

    /// @dev Common checks for valid tick inputs.
    function checkTicks(int24 tickLower, int24 tickUpper) private pure {
        if (tickLower >= tickUpper) revert TLU();
        if (tickLower < TickMath.MIN_TICK) revert TLM();
        if (tickUpper > TickMath.MAX_TICK) revert TUM();
    }

    struct ModifyPositionParams {
        // the address that owns the position
        address owner;
        // the lower and upper tick of the position
        int24 tickLower;
        int24 tickUpper;
        // any change in liquidity
        int128 liquidityDelta;
    }

    /// @dev Effect some changes to a position
    /// @param params the position details and the change to the position's liquidity to effect
    /// @return position a storage pointer referencing the position with the given owner and tick range
    /// @return amount0 the amount of amount0 owed to the pool, negative if the pool should pay the recipient
    /// @return amount1 the amount of amount1 owed to the pool, negative if the pool should pay the recipient
    function _modifyPosition(
        bytes32 optionPoolKeyHash,
        ModifyPositionParams memory params
    )
        private
        noDelegateCall
        returns (Position.Info storage position, int256 amount0, int256 amount1)
    {
        checkTicks(params.tickLower, params.tickUpper);

        Slot0 memory _slot0 = slots0[optionPoolKeyHash]; // SLOAD for gas optimization
        optionPoolKeyHash = optionPoolKeyHashAliases[optionPoolKeyHash]; // get rootPoolHash

        position = _updatePosition(
            params.owner,
            optionPoolKeyHash, // rootPoolHash
            params.tickLower,
            params.tickUpper,
            params.liquidityDelta,
            _slot0.tick
        );

        if (params.liquidityDelta != 0) {
            if (_slot0.tick < params.tickLower) {
                // current tick is below the passed range; liquidity can only become in range by crossing from left to
                // right, when we'll need _more_ amount0 (it's becoming more valuable) so user must provide it
                amount0 = SqrtPriceMath.getAmount0Delta(
                    TickMath.getSqrtRatioAtTick(params.tickLower),
                    TickMath.getSqrtRatioAtTick(params.tickUpper),
                    params.liquidityDelta
                );
            } else if (_slot0.tick < params.tickUpper) {
                // current tick is inside the passed range
                uint128 liquidityBefore = liquidities[optionPoolKeyHash]; // SLOAD for gas optimization

                amount0 = SqrtPriceMath.getAmount0Delta(
                    _slot0.sqrtPriceX96,
                    TickMath.getSqrtRatioAtTick(params.tickUpper),
                    params.liquidityDelta
                );
                amount1 = SqrtPriceMath.getAmount1Delta(
                    TickMath.getSqrtRatioAtTick(params.tickLower),
                    _slot0.sqrtPriceX96,
                    params.liquidityDelta
                );

                liquidities[optionPoolKeyHash] = params.liquidityDelta < 0
                    ? liquidityBefore - uint128(-params.liquidityDelta)
                    : liquidityBefore + uint128(params.liquidityDelta);
            } else {
                // current tick is above the passed range; liquidity can only become in range by crossing from right to
                // left, when we'll need _more_ amount1 (it's becoming more valuable) so user must provide it
                amount1 = SqrtPriceMath.getAmount1Delta(
                    TickMath.getSqrtRatioAtTick(params.tickLower),
                    TickMath.getSqrtRatioAtTick(params.tickUpper),
                    params.liquidityDelta
                );
            }
        }
    }

    // / @dev Gets and updates a position with the given liquidity delta
    // / @param owner the owner of the position
    // / @param tickLower the lower tick of the position's tick range
    // / @param tickUpper the upper tick of the position's tick range
    // / @param tick the current tick, passed to avoid sloads
    function _updatePosition(
        address owner,
        bytes32 optionPoolKeyHash,
        int24 tickLower,
        int24 tickUpper,
        int128 liquidityDelta,
        int24 tick
    ) private returns (Position.Info storage position) {
        // SLOAD
        mapping(int24 => Tick.Info) storage optionPoolTicks = ticks[
            optionPoolKeyHash
        ];

        position = positions[optionPoolKeyHash].get(
            owner,
            tickLower,
            tickUpper
        );

        uint256 _feeGrowthGlobal0X128 = feeGrowthsGlobal0X128[
            optionPoolKeyHash
        ]; // SLOAD for gas optimization
        uint256 _feeGrowthGlobal1X128 = feeGrowthsGlobal1X128[
            optionPoolKeyHash
        ]; // SLOAD for gas optimization

        // if we need to update the ticks, do it
        bool flippedLower;
        bool flippedUpper;
        if (liquidityDelta != 0) {
            flippedLower = optionPoolTicks.update(
                tickLower,
                tick,
                liquidityDelta,
                _feeGrowthGlobal0X128,
                _feeGrowthGlobal1X128,
                false,
                maxLiquidityPerTick
            );
            flippedUpper = optionPoolTicks.update(
                tickUpper,
                tick,
                liquidityDelta,
                _feeGrowthGlobal0X128,
                _feeGrowthGlobal1X128,
                true,
                maxLiquidityPerTick
            );

            if (flippedLower) {
                tickBitmap[optionPoolKeyHash].flipTick(tickLower, tickSpacing);
            }
            if (flippedUpper) {
                tickBitmap[optionPoolKeyHash].flipTick(tickUpper, tickSpacing);
            }
        }

        (
            uint256 feeGrowthInside0X128,
            uint256 feeGrowthInside1X128
        ) = optionPoolTicks.getFeeGrowthInside(
                tickLower,
                tickUpper,
                tick,
                _feeGrowthGlobal0X128,
                _feeGrowthGlobal1X128
            );

        position.update(
            liquidityDelta,
            feeGrowthInside0X128,
            feeGrowthInside1X128
        );

        // clear any tick data that is no longer needed
        if (liquidityDelta < 0) {
            if (flippedLower) {
                optionPoolTicks.clear(tickLower);
            }
            if (flippedUpper) {
                optionPoolTicks.clear(tickUpper);
            }
        }
    }

    /// @dev noDelegateCall is applied indirectly via _modifyPosition
    function mint(
        address recipient,
        bytes32 optionPoolKeyHash,
        int24 tickLower,
        int24 tickUpper,
        uint128 amount,
        bytes calldata
    )
        external
        override
        GlobalLock
        OnlyComboContract
        returns (uint256 amount0, uint256 amount1)
    {
        // check if option pool is not yet expired
        checkNotExpired(optionPoolKeyStructs[optionPoolKeyHash].expiry);

        if (!slots0[optionPoolKeyHash].unlocked) revert LOK();
        require(amount > 0);

        (, int256 amount0Int, int256 amount1Int) = _modifyPosition(
            optionPoolKeyHash,
            ModifyPositionParams({
                owner: recipient,
                tickLower: tickLower,
                tickUpper: tickUpper,
                liquidityDelta: int256(uint256(amount)).toInt128()
            })
        );

        amount0 = uint256(amount0Int);
        amount1 = uint256(amount1Int);

        emit Mint(
            optionPoolKeyHash,
            msg.sender,
            recipient,
            tickLower,
            tickUpper,
            amount,
            amount0,
            amount1
        );
    }

    function collect(
        address recipient,
        bytes32 optionPoolKeyHash,
        int24 tickLower,
        int24 tickUpper,
        uint128 amountRequested
    )
        external
        override
        GlobalLock
        OnlyComboContract
        returns (uint128 amount)
    {
        if (!slots0[optionPoolKeyHash].unlocked) revert LOK();
        // we don't need to checkTicks here, because invalid positions will never have non-zero tokensOwed
        // Position.Info storage position = positions.get(msg.sender, tickLower, tickUpper);
        // @ AlcorFinance:
        Position.Info storage position = positions[
            optionPoolKeyHashAliases[optionPoolKeyHash]
        ].get(recipient, tickLower, tickUpper);

        amount = amountRequested > position.tokensOwed
            ? position.tokensOwed
            : amountRequested;
    

        if (amount > 0) {
            position.tokensOwed -= amount;
        }

        emit Collect(
            optionPoolKeyHash,
            msg.sender,
            recipient,
            tickLower,
            tickUpper,
            amount
        );
    }

    /// @dev noDelegateCall is applied indirectly via _modifyPosition
    function burn(
        // @ AlcorFinance:
        address owner,
        bytes32 optionPoolKeyHash,
        int24 tickLower,
        int24 tickUpper,
        uint128 amount
    )
        external
        override
        OnlyComboContract
        returns (uint256 amount0, uint256 amount1)
    {
        if (!slots0[optionPoolKeyHash].unlocked) revert LOK();
        unchecked {
            (
                Position.Info storage position,
                int256 amount0Int,
                int256 amount1Int
            ) = _modifyPosition(
                    optionPoolKeyHash,
                    ModifyPositionParams({
                        // @ AlcorFinance:
                        owner: owner, //msg.sender,
                        tickLower: tickLower,
                        tickUpper: tickUpper,
                        liquidityDelta: -int256(uint256(amount)).toInt128()
                    })
                );

            amount0 = uint256(-amount0Int);
            amount1 = uint256(-amount1Int);

            if (amount0 > 0 || amount1 > 0) {
                position.tokensOwed = position.tokensOwed + uint128(amount0) + uint128(amount1);
            }
            // @ AlcorFinance: msg.sender => owner
            emit Burn(
                optionPoolKeyHash,
                owner,
                tickLower,
                tickUpper,
                amount,
                amount0,
                amount1
            );
        }
    }

    struct SwapCache {
        // the protocol fee for the input token
        uint8 feeProtocol;
        // liquidity at the beginning of the swap
        uint128 liquidityStart;
        // @ AlcorFinance:
        bool exactInput;
    }

    // the top level state of the swap, the results of which are recorded in storage at the end
    struct SwapState {
        // the amount remaining to be swapped in/out of the input/output asset
        int256 amountSpecifiedRemaining;
        // the amount already swapped out/in of the output/input asset
        int256 amountCalculated;
        // current sqrt(price)
        uint160 sqrtPriceX96;
        // the tick associated with the current price
        int24 tick;
        // the global fee growth of the input token
        uint256 feeGrowthGlobalX128;
        // amount of input token paid as protocol fee
        uint128 protocolFee;
        // the current liquidity in range
        uint128 liquidity;
        // @ AlcorFinance:
        uint256 feeAmountTotal;
    }

    struct StepComputations {
        // the price at the beginning of the step
        uint160 sqrtPriceStartX96;
        // the next tick to swap to from the current tick in the swap direction
        int24 tickNext;
        // whether tickNext is initialized or not
        bool initialized;
        // sqrt(price) for the next tick (1/0)
        uint160 sqrtPriceNextX96;
        // how much is being swapped in in this step
        uint256 amountIn;
        // how much is being swapped out
        uint256 amountOut;
        // how much fee is being paid in
        uint256 feeAmount;
        // @ AlcorFinance:
        int128 liquidityNet;
    }

    function swap(
        SwapInputs memory swapInputs
    )
        external
        override
        GlobalLock
        OnlyComboContract
        noDelegateCall
        returns (int256 amount0, int256 amount1, uint256 feeAmountTotal)
    {
        // check if option pool is not yet expired
        checkNotExpired(
            optionPoolKeyStructs[swapInputs.optionPoolKeyHash].expiry
        );

        if (swapInputs.amountSpecified == 0) revert AS();

        Slot0 memory slot0Start = slots0[swapInputs.optionPoolKeyHash]; // currentPool_Slot0
        bytes32 optionPoolKeyHashRoot = optionPoolKeyHashAliases[ // get rootPoolHash
            swapInputs.optionPoolKeyHash
        ];

        if (!slot0Start.unlocked) revert LOK();
        require(
            swapInputs.zeroForOne
                ? swapInputs.sqrtPriceLimitX96 < slot0Start.sqrtPriceX96 &&
                    swapInputs.sqrtPriceLimitX96 > TickMath.MIN_SQRT_RATIO
                : swapInputs.sqrtPriceLimitX96 > slot0Start.sqrtPriceX96 &&
                    swapInputs.sqrtPriceLimitX96 < TickMath.MAX_SQRT_RATIO,
            "SPL"
        );

        slots0[swapInputs.optionPoolKeyHash].unlocked = false; // currentPool_Slot0

        SwapCache memory cache = SwapCache({
            liquidityStart: liquidities[optionPoolKeyHashRoot],
            feeProtocol: swapInputs.zeroForOne
                ? (feeProtocol % 16)
                : (feeProtocol >> 4),
            exactInput: swapInputs.amountSpecified > 0
        });

        SwapState memory state = SwapState({
            amountSpecifiedRemaining: swapInputs.amountSpecified,
            amountCalculated: 0,
            sqrtPriceX96: slot0Start.sqrtPriceX96,
            tick: slot0Start.tick,
            feeGrowthGlobalX128: swapInputs.zeroForOne
                ? feeGrowthsGlobal0X128[optionPoolKeyHashRoot]
                : feeGrowthsGlobal1X128[optionPoolKeyHashRoot],
            protocolFee: 0,
            liquidity: cache.liquidityStart, 
            feeAmountTotal: 0
        });

        // continue swapping as long as we haven't used the entire input/output and haven't reached the price limit
        while (
            state.amountSpecifiedRemaining != 0 &&
            state.sqrtPriceX96 != swapInputs.sqrtPriceLimitX96
        ) {
            StepComputations memory step;

            step.sqrtPriceStartX96 = state.sqrtPriceX96;

            (step.tickNext, step.initialized) = tickBitmap[
                optionPoolKeyHashRoot
            ].nextInitializedTickWithinOneWord(
                    state.tick,
                    tickSpacing,
                    swapInputs.zeroForOne
                );

            // ensure that we do not overshoot the min/max tick, as the tick bitmap is not aware of these bounds
            if (step.tickNext < TickMath.MIN_TICK) {
                step.tickNext = TickMath.MIN_TICK;
            } else if (step.tickNext > TickMath.MAX_TICK) {
                step.tickNext = TickMath.MAX_TICK;
            }

            // get the price for the next tick
            step.sqrtPriceNextX96 = TickMath.getSqrtRatioAtTick(step.tickNext);

            // compute values to swap to the target tick, price limit, or point where input/output amount is exhausted
            (
                state.sqrtPriceX96,
                step.amountIn,
                step.amountOut,
                step.feeAmount
            ) = SwapMath.computeSwapStep(
                state.sqrtPriceX96,
                (
                    swapInputs.zeroForOne
                        ? step.sqrtPriceNextX96 < swapInputs.sqrtPriceLimitX96
                        : step.sqrtPriceNextX96 > swapInputs.sqrtPriceLimitX96
                )
                    ? swapInputs.sqrtPriceLimitX96
                    : step.sqrtPriceNextX96,
                state.liquidity,
                state.amountSpecifiedRemaining,
                fee
            );

            state.feeAmountTotal += step.feeAmount;

            if (cache.exactInput) {
                // safe because we test that amountSpecified > amountIn + feeAmount in SwapMath
                unchecked {
                    state.amountSpecifiedRemaining -= (step.amountIn +
                        step.feeAmount).toInt256();
                }
                state.amountCalculated -= step.amountOut.toInt256();
            } else {
                unchecked {
                    state.amountSpecifiedRemaining += step.amountOut.toInt256();
                }
                state.amountCalculated += (step.amountIn + step.feeAmount)
                    .toInt256();
            }


            // if the protocol fee is on, calculate how much is owed, decrement feeAmount, and increment protocolFee
            if (cache.feeProtocol > 0) {
                unchecked {
                    uint256 delta = step.feeAmount / cache.feeProtocol;
                    step.feeAmount -= delta;
                    state.protocolFee += uint128(delta);
                }
            }

            // update global fee tracker
            if (state.liquidity > 0) {
                unchecked {
                    state.feeGrowthGlobalX128 += FullMath.mulDiv(
                        step.feeAmount,
                        FixedPoint128.Q128,
                        state.liquidity
                    );
                }
            }

            // shift tick if we reached the next price
            if (state.sqrtPriceX96 == step.sqrtPriceNextX96) {
                // if the tick is initialized, run the tick transition
                if (step.initialized) {
                    step.liquidityNet = ticks[optionPoolKeyHashRoot].cross(
                        step.tickNext,
                        (
                            swapInputs.zeroForOne
                                ? state.feeGrowthGlobalX128
                                : feeGrowthsGlobal0X128[optionPoolKeyHashRoot]
                        ),
                        (
                            swapInputs.zeroForOne
                                ? feeGrowthsGlobal1X128[optionPoolKeyHashRoot]
                                : state.feeGrowthGlobalX128
                        )
                    );
                    // if we're moving leftward, we interpret liquidityNet as the opposite sign
                    // safe because liquidityNet cannot be type(int128).min
                    unchecked {
                        if (swapInputs.zeroForOne)
                            step.liquidityNet = -step.liquidityNet;
                    }

                    state.liquidity = step.liquidityNet < 0
                        ? state.liquidity - uint128(-step.liquidityNet)
                        : state.liquidity + uint128(step.liquidityNet);
                }

                unchecked {
                    state.tick = swapInputs.zeroForOne
                        ? step.tickNext - 1
                        : step.tickNext;
                }
            } else if (state.sqrtPriceX96 != step.sqrtPriceStartX96) {
                // recompute unless we're on a lower tick boundary (i.e. already transitioned ticks), and haven't moved
                state.tick = TickMath.getTickAtSqrtRatio(state.sqrtPriceX96);
            }
 
        }

        // update tick and write an oracle entry if the tick change
        if (state.tick != slot0Start.tick) {
            (
                slots0[swapInputs.optionPoolKeyHash].sqrtPriceX96,
                slots0[swapInputs.optionPoolKeyHash].tick
            ) = (state.sqrtPriceX96, state.tick);
        } else {
            // otherwise just update the price
            slots0[swapInputs.optionPoolKeyHash].sqrtPriceX96 = state
                .sqrtPriceX96;
        }
        feeAmountTotal = state.feeAmountTotal;

        // update liquidity if it changed
        if (cache.liquidityStart != state.liquidity)
            liquidities[optionPoolKeyHashRoot] = state.liquidity;

        // update fee growth global and, if necessary, protocol fees
        // overflow is acceptable, protocol has to withdraw before it hits type(uint128).max fees
        if (swapInputs.zeroForOne) {
            feeGrowthsGlobal0X128[optionPoolKeyHashRoot] = state
                .feeGrowthGlobalX128;
            unchecked {
                if (state.protocolFee > 0)
                    feeProtocolAmount += state.protocolFee;
            }
        } else {
            feeGrowthsGlobal1X128[optionPoolKeyHashRoot] = state
                .feeGrowthGlobalX128;
            unchecked {
                if (state.protocolFee > 0)
                    feeProtocolAmount += state.protocolFee;
            }
        }
        
        unchecked {
            (amount0, amount1) = swapInputs.zeroForOne == cache.exactInput
                ? (
                    swapInputs.amountSpecified - state.amountSpecifiedRemaining,
                    state.amountCalculated
                )
                : (
                    state.amountCalculated,
                    swapInputs.amountSpecified - state.amountSpecifiedRemaining
                );
        }

        emit Swap(
            swapInputs.optionPoolKeyHash,
            msg.sender,
            amount0,
            amount1,
            state.sqrtPriceX96,
            state.liquidity,
            state.tick
        );

        slots0[swapInputs.optionPoolKeyHash].unlocked = true;
    }

    function setFeeProtocol(
        uint8 feeProtocol0,
        uint8 feeProtocol1
    ) external override GlobalLock OnlyOwner {
        unchecked {
            require(
                (feeProtocol0 == 0 ||
                    (feeProtocol0 >= 4 && feeProtocol0 <= 10)) &&
                    (feeProtocol1 == 0 ||
                        (feeProtocol1 >= 4 && feeProtocol1 <= 10))
            );
            uint8 feeProtocolOld = feeProtocol;
            feeProtocol = feeProtocol0 + (feeProtocol1 << 4);
            emit SetFeeProtocol(
                feeProtocolOld % 16,
                feeProtocolOld >> 4,
                feeProtocol0,
                feeProtocol1
            );
        }
    }

    // @dev this method supports transfers
    function collectProtocol(
        address recipient,
        uint128 amountRequested
    )
        external
        override
        GlobalLock
        OnlyOwner
        returns (uint128 amount)
    {
        amount = amountRequested > feeProtocolAmount
            ? feeProtocolAmount
            : amountRequested;
        unchecked {
            if (amount > 0) {
                if (amount == feeProtocolAmount) amount--; // ensure that the slot is not cleared, for gas savings
                feeProtocolAmount -= amount;
                TransferHelper.safeTransfer(token, recipient, amount);
            }
        }
        // actually it's not essential to update the pool balances, because protocol fee will be usually greatly lower than tvl

        emit CollectProtocol(msg.sender, recipient, amount);
    }
}
// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

import {IAllowanceTransfer} from "./lib_permit2_src_interfaces_IAllowanceTransfer.sol";
import {SafeERC20, IERC20} from "./lib_openzeppelin-contracts_contracts_token_ERC20_utils_SafeERC20.sol";
import {PayMaster} from "./src_library_PayMaster.sol";
import {PositionKey} from "./src_types_PositionKey.sol";
import {PositionIdLib, PositionId} from "./src_types_PositionId.sol";
import {IPoolPartyPositionFactory} from "./src_interfaces_IPoolPartyPositionFactory.sol";
import "./src_storage_PoolPartyPositionManagerStorage.sol";

/**
 * @title Core Library
 * @notice This library provides core functionalities for managing Uniswap V3 pool positions,
 * including creating, adding, removing liquidity, collecting rewards, closing pools, and withdrawing.
 */
// aderyn-ignore-next-line(reused-contract-name)
library Core {
    using SafeERC20 for IERC20;
    using PositionIdLib for PositionKey;

    /**
     * @notice Creates a new pool position.
     * @param s The storage reference for the pool position.
     * @param _params The parameters required to create the position.
     * @return positionId The ID of the created position.
     */
    // aderyn-ignore-next-line(state-variable-changes-without-events)
    function createPosition(
        Storage storage s,
        IPoolPartyPositionManager.CreatePositionParams calldata _params
    ) external returns (PositionId positionId) {
        require(
            _params.permitBatch.details.length == 2,
            Errors.PermitBatchInvalid()
        );
        require(
            _params.permitBatch.spender == address(this),
            Errors.PermitSpenderInvalid()
        );

        IAllowanceTransfer.PermitDetails memory details0 = _params
            .permitBatch
            .details[0];
        IAllowanceTransfer.PermitDetails memory details1 = _params
            .permitBatch
            .details[1];
        address currency0 = details0.token;
        address currency1 = details1.token;

        IPoolPartyPositionManager.FeatureSettings
            memory featureSettings = _params.featureSettings;

        IPoolPartyPosition poolPosition = IPoolPartyPositionFactory(
            s.i_poolPositionFactory
        ).create(
                IPoolPartyPositionStructs.ConstructorParams({
                    admin: s.i_admin,
                    upgrader: s.i_upgrader,
                    manager: address(this),
                    nonfungiblePositionManager: s.i_nonfungiblePositionManager,
                    uniswapV3Factory: s.i_uniswapV3Factory,
                    uniswapV3SwapRouter: s.i_swapRouter,
                    stableCurrency: s.i_stableCurrency,
                    WETH9: s.i_WETH9,
                    operator: msg.sender,
                    operatorFee: featureSettings.operatorFee,
                    protocolFeeRecipient: s.protocolFeeRecipient,
                    protocolFee: s.protocolFee,
                    currency0: currency0,
                    currency1: currency1,
                    fee: _params.fee,
                    tickLower: _params.tickLower,
                    tickUpper: _params.tickUpper,
                    name: featureSettings.name
                })
            );

        IAllowanceTransfer(s.i_permit2).permit(
            msg.sender,
            _params.permitBatch,
            _params.signature
        );
        uint160 amount0Desired = details0.amount;
        uint160 amount1Desired = details1.amount;

        if (poolPosition.poolPositionView().inRange() == 0) {
            transferETHOrToken(
                s,
                poolPosition,
                currency0,
                amount0Desired,
                address(this)
            );
            transferETHOrToken(
                s,
                poolPosition,
                currency1,
                amount1Desired,
                address(this)
            );
        } else if (poolPosition.poolPositionView().inRange() == 1) {
            amount0Desired = 0;
            transferETHOrToken(
                s,
                poolPosition,
                currency1,
                amount1Desired,
                address(this)
            );
        } else {
            amount1Desired = 0;
            transferETHOrToken(
                s,
                poolPosition,
                currency0,
                amount0Desired,
                address(this)
            );
        }

        //slither-disable-next-line unused-return,reentrancy-no-eth
        (positionId, , , , ) = poolPosition.mintPosition(
            IPoolPartyPositionStructs.MintPositionParams({
                amount0Desired: amount0Desired,
                amount1Desired: amount1Desired,
                amount0Min: _params.amount0Min,
                amount1Min: _params.amount1Min,
                deadline: _params.deadline
            })
        );

        s.operatorByPositionId[positionId] = msg.sender;
        s.positionByInvestorAndId[msg.sender][positionId] = address(
            poolPosition
        );
        s.positionsByInvestor[msg.sender].push(address(poolPosition));
        s.featureSettings[positionId] = featureSettings;
        s.positions.push(address(poolPosition));
    }

    /**
     * @notice Adds liquidity to an existing pool position.
     * @param s The storage reference for the pool position.
     * @param _params The parameters required to add liquidity.
     * @return liquidity The amount of liquidity added.
     * @return amount0 The amount of currency0 added.
     * @return amount1 The amount of currency1 added.
     */
    // aderyn-ignore-next-line(state-variable-changes-without-events)
    function addLiquidity(
        Storage storage s,
        IPoolPartyPositionManager.AddLiquidityParams calldata _params
    ) external returns (uint128 liquidity, uint256 amount0, uint256 amount1) {
        PositionId positionId = _params.positionId;

        IPoolPartyPosition position = IPoolPartyPositionFactory(
            s.i_poolPositionFactory
        ).getPoolPartyPosition(positionId);

        require(address(position) != address(0), Errors.PoolPositionNotFound());
        require(
            !position.poolPositionView().isClosed(),
            Errors.PoolPositionAlreadyClosed()
        );
        require(
            _params.permit.details.token == s.i_stableCurrency,
            Errors.IsNotStableCurrency()
        );
        require(
            _params.permit.spender == address(this),
            Errors.PermitSpenderInvalid()
        );
        address investor = msg.sender;
        address operator = s.operatorByPositionId[positionId];
        if (
            investor != operator &&
            s.positionByInvestorAndId[investor][positionId] == address(0)
        ) {
            s.positionByInvestorAndId[investor][positionId] = address(position);
            s.positionsByInvestor[investor].push(address(position));
        }

        uint256 currentInvLiquidity = IPoolPartyPosition(address(position))
            .poolPositionView()
            .liquidityOf(investor);
        if (
            investor != operator &&
            currentInvLiquidity == 0 &&
            !s.positionInvestedBy[positionId][investor]
        ) {
            s.totalInvestorsByPosition[positionId]++;
            s.positionInvestedBy[positionId][investor] = true;
        }

        IAllowanceTransfer(s.i_permit2).permit(
            investor,
            _params.permit,
            _params.signature
        );
        uint160 amountStableCurrency = _params.permit.details.amount;
        // aderyn-ignore-next-line(unsafe-erc20-functions)
        IAllowanceTransfer(s.i_permit2).transferFrom(
            investor,
            address(this),
            amountStableCurrency,
            s.i_stableCurrency
        );

        (
            uint256 amount0StableCurrency,
            uint256 amount1StableCurrency
        ) = PayMaster.computeStableCurrencyToPairTokenAmounts(
                position.poolPositionView().key(),
                amountStableCurrency
            );

        if (position.poolPositionView().inRange() == 1) {
            amount0StableCurrency = 0;
            amount1StableCurrency = amountStableCurrency;
        } else if (position.poolPositionView().inRange() == -1) {
            amount0StableCurrency = amountStableCurrency;
            amount1StableCurrency = 0;
        }

        IERC20(s.i_stableCurrency).forceApprove(
            address(position),
            amountStableCurrency
        );

        return
            position.increaseLiquidity(
                IPoolPartyPositionStructs.IncreaseLiquidityParams({
                    investor: investor,
                    amount0StableCurrency: amount0StableCurrency,
                    amount1StableCurrency: amount1StableCurrency,
                    deadline: _params.deadline,
                    swap: _params.swap,
                    ignoreSlippage: _params.ignoreSlippage
                })
            );
    }

    /**
     * @notice Removes liquidity from an existing pool position.
     * @param s The storage reference for the pool position.
     * @param _params The parameters required to remove liquidity.
     * @return liquidity The amount of liquidity removed.
     * @return amount0 The amount of currency0 removed.
     * @return amount1 The amount of currency1 removed.
     */
    // aderyn-ignore-next-line(state-variable-changes-without-events)
    function removeLiquidity(
        Storage storage s,
        IPoolPartyPositionManager.RemoveLiquidityParams calldata _params
    ) external returns (uint128 liquidity, uint256 amount0, uint256 amount1) {
        address investor = msg.sender;

        uint256 percentageToRemove = (s.totalInvestmentsByInvestor[investor] *
            _params.percentage) /
            (Constants.HUNDRED_PERCENT *
                Constants.REMOVE_PERCENTAGE_MULTIPLIER);

        if (percentageToRemove >= s.totalInvestmentsByInvestor[investor]) {
            s.totalInvestmentsByInvestor[investor] = 0;
        } else {
            s.totalInvestmentsByInvestor[investor] -= percentageToRemove;
        }

        PositionId positionId = _params.positionId;
        IPoolPartyPosition position = IPoolPartyPositionFactory(
            s.i_poolPositionFactory
        ).getPoolPartyPosition(positionId);

        require(address(position) != address(0), Errors.PoolPositionNotFound());
        require(
            !position.poolPositionView().isClosed(),
            Errors.PoolPositionAlreadyClosed()
        );

        (liquidity, amount0, amount1) = position.decreaseLiquidity(
            IPoolPartyPositionStructs.DecreaseLiquidityParams({
                investor: investor,
                percentage: _params.percentage,
                amount0Min: _params.amount0Min,
                amount1Min: _params.amount1Min,
                deadline: _params.deadline,
                swap: _params.swap,
                swapAllToStableCurrency: _params.swapAllToStableCurrency
            })
        );

        address operator = s.operatorByPositionId[positionId];

        if (
            investor != operator &&
            s.positionInvestedBy[positionId][investor] &&
            _params.percentage ==
            (Constants.HUNDRED_PERCENT * Constants.REMOVE_PERCENTAGE_MULTIPLIER)
        ) {
            if (s.totalInvestorsByPosition[positionId] > 0) {
                s.totalInvestorsByPosition[positionId]--;
            }
            s.positionInvestedBy[positionId][investor] = false;
        }
    }

    /**
     * @notice Collects rewards from an existing pool position.
     * @param s The storage reference for the pool position.
     * @param _params The parameters required to collect rewards.
     * @return amount0 The amount of currency0 collected.
     * @return amount1 The amount of currency1 collected.
     */
    function collectRewards(
        Storage storage s,
        IPoolPartyPositionManager.CollectParams calldata _params
    ) external returns (uint256 amount0, uint256 amount1) {
        IPoolPartyPosition position = IPoolPartyPositionFactory(
            s.i_poolPositionFactory
        ).getPoolPartyPosition(_params.positionId);
        require(address(position) != address(0), Errors.PoolPositionNotFound());

        return
            position.collect(
                IPoolPartyPositionStructs.CollectParams({
                    investor: msg.sender,
                    deadline: _params.deadline,
                    swap: _params.swap
                })
            );
    }

    /**
     * @notice Closes an existing pool position.
     * @param s The storage reference for the pool position.
     * @param _params The parameters required to close the pool.
     * @return liquidity The amount of liquidity removed.
     * @return amount0 The amount of currency0 removed.
     * @return amount1 The amount of currency1 removed.
     */
    // aderyn-ignore-next-line(state-variable-changes-without-events)
    function closePool(
        Storage storage s,
        IPoolPartyPositionManager.ClosePoolParams calldata _params
    ) external returns (uint128, uint256, uint256) {
        PositionId positionId = _params.positionId;
        IPoolPartyPosition position = IPoolPartyPositionFactory(
            s.i_poolPositionFactory
        ).getPoolPartyPosition(positionId);
        require(address(position) != address(0), Errors.PoolPositionNotFound());
        require(
            !position.poolPositionView().isClosed(),
            Errors.PoolPositionAlreadyClosed()
        );

        address operator = msg.sender;
        s.totalInvestmentsByInvestor[operator] = 0;
        s.positionInvestedBy[positionId][operator] = false;

        return
            position.closePosition(
                IPoolPartyPositionStructs.ClosePositionParams({
                    operator: operator,
                    deadline: _params.deadline,
                    swapAllToStableCurrency: _params.swapAllToStableCurrency
                })
            );
    }

    /**
     * @notice Withdraws from an existing pool position.
     * @param s The storage reference for the pool position.
     * @param _params The parameters required to withdraw.
     * @return currency0 The amount of currency0 withdrawn.
     * @return currency1 The amount of currency1 withdrawn.
     * @return collected0 The amount of currency0 collected.
     * @return collected1 The amount of currency1 collected.
     */
    // aderyn-ignore-next-line(state-variable-changes-without-events)
    function withdraw(
        Storage storage s,
        IPoolPartyPositionManager.WithdrawParams calldata _params
    )
        external
        returns (
            uint256 currency0,
            uint256 currency1,
            uint256 collected0,
            uint256 collected1
        )
    {
        PositionId positionId = _params.positionId;
        IPoolPartyPosition position = IPoolPartyPositionFactory(
            s.i_poolPositionFactory
        ).getPoolPartyPosition(_params.positionId);
        require(address(position) != address(0), Errors.PoolPositionNotFound());

        address operator = s.operatorByPositionId[positionId];
        address investor = msg.sender;
        if (
            investor != operator && s.totalInvestorsByPosition[positionId] > 0
        ) {
            s.totalInvestorsByPosition[positionId]--;
        }
        s.totalInvestmentsByInvestor[investor] = 0;
        s.positionInvestedBy[positionId][investor] = false;

        // slither-disable-start unused-return
        return
            position.withdraw(
                IPoolPartyPositionStructs.WithdrawParams({
                    investor: investor,
                    deadline: _params.deadline,
                    swap: _params.swap
                })
            );
        // slither-disable-end unused-return
    }

    function moveRange(
        Storage storage s,
        IPoolPartyPositionManager.MoveRangeParams calldata _params
    ) external {
        PositionId positionId = _params.positionId;
        IPoolPartyPosition position = IPoolPartyPositionFactory(
            s.i_poolPositionFactory
        ).getPoolPartyPosition(positionId);
        require(address(position) != address(0), Errors.PoolPositionNotFound());
        require(
            !position.poolPositionView().isClosed(),
            Errors.PoolPositionAlreadyClosed()
        );

        position.moveRange(
            IPoolPartyPositionStructs.MoveRangeParams({
                operator: msg.sender,
                tickLower: _params.tickLower,
                tickUpper: _params.tickUpper,
                swapAmount0: _params.swapAmount0,
                swapAmount0Minimum: _params.swapAmount0Minimum,
                swapAmount1: _params.swapAmount1,
                swapAmount1Minimum: _params.swapAmount1Minimum,
                multihopSwapPath0: _params.multihopSwapPath0,
                multihopSwapPath1: _params.multihopSwapPath1,
                deadline: _params.deadline,
                ignoreSlippage: _params.ignoreSlippage
            })
        );
    }

    /**
     * @notice Resets the maximum investment for a list of accounts.
     * @param s The storage reference for the pool position.
     * @param _accounts The list of accounts to reset.
     */
    // aderyn-ignore-next-line(state-variable-changes-without-events, costly-operations-inside-loops)
    function resetMaxInvestment(
        Storage storage s,
        address[] memory _accounts
    ) external {
        // slither-disable-start calls-loop
        uint256 length = _accounts.length;
        // aderyn-ignore-next-line(costly-operations-inside-loops)
        for (uint256 i = 0; i < length; i++) {
            address investor = _accounts[i];
            address[] memory positions = s.positionsByInvestor[investor];
            uint256 posLength = positions.length;
            // aderyn-ignore-next-line(costly-operations-inside-loops)
            for (uint256 j = 0; j < posLength; j++) {
                IPoolPartyPosition position = IPoolPartyPosition(positions[j]);
                PositionId positionId = position
                    .poolPositionView()
                    .key()
                    .toId();
                s.positionInvestedBy[positionId][investor] = false;
            }
            s.totalInvestmentsByInvestor[investor] = 0;
        }
        // slither-disable-end calls-loop
    }

    /**
     * @notice Transfers ETH or a token to a recipient address if the contract holds enough ETH.
     * Otherwise, transfer the token to the recipient address using the permit function.
     * @param s The storage reference for the pool position.
     * @param _poolPosition The pool position to transfer to.
     * @param _token The token to transfer.
     * @param _value The amount of token to transfer.
     * @param _recipient The address to receive the token.
     */
    function transferETHOrToken(
        Storage storage s,
        IPoolPartyPosition _poolPosition,
        address _token,
        uint256 _value,
        address _recipient
    ) public {
        if (_value == 0) {
            return;
        }
        if (_token == s.i_WETH9 && address(this).balance >= _value) {
            TransferHelper.safeTransferETH(address(_poolPosition), _value);
        } else {
            // aderyn-ignore-next-line
            IAllowanceTransfer(s.i_permit2).transferFrom(
                msg.sender,
                _recipient,
                uint160(_value),
                _token
            );
            IERC20(_token).forceApprove(address(_poolPosition), _value);
        }
    }
}
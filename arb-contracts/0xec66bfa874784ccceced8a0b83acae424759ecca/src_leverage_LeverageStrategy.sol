// SPDX-License-Identifier: UNLICENSED

// Copyright (c) 2024 Jones DAO - All rights reserved
// Jones DAO: https://www.jonesdao.io/

pragma solidity ^0.8.20;

import {FixedPointMathLib} from "./lib_solmate_src_utils_FixedPointMathLib.sol";

import {UpgradeableOperableKeepable} from "./src_governance_UpgradeableOperableKeepable.sol";
import {IERC20} from "./lib_openzeppelin-contracts_contracts_token_ERC20_IERC20.sol";

import {IPayBack} from "./src_interfaces_jusdc_IPayBack.sol";
import {IUnderlyingVault} from "./src_interfaces_jusdc_IUnderlyingVault.sol";
import {IEnforcePayBackCallback} from "./src_interfaces_jusdc_IEnforcePayBackCallback.sol";

import {ILeverageViewer} from "./src_interfaces_leverage_ILeverageViewer.sol";
import {ILeverageStrategy} from "./src_interfaces_leverage_ILeverageStrategy.sol";
import {IjGlvRouter} from "./src_interfaces_glv_IjGlvRouter.sol";

contract LeverageStrategy is ILeverageStrategy, IPayBack, UpgradeableOperableKeepable {
    using FixedPointMathLib for uint256;

    struct CallbackData {
        uint256 shares;
        uint256 jGlvToRedeem;
        uint256 levjGlvToRedeem;
        address receiver;
        uint256 underlyingAssets;
        uint256 totalAssets;
    }

    /// @notice Stack too deep
    struct LevVars {
        address thisAddress;
        uint256 availableForBorrowing;
        uint256 oldLeverage;
        uint256 stablesInStrategy;
        uint256 stablesToBorrow;
        uint256 newjGM;
        uint256 underlying;
        uint256 currentBalance;
        uint256 jGMNeeded;
        uint256 newLeverage;
    }

    /// @notice Stack too deep
    struct PayBackVars {
        address thisAddress;
        uint256 strategyStables;
        uint256 expectedStables;
        uint256 gmxIncentive;
        uint256 incentives;
        uint256 length;
        uint256 shares;
    }

    /* -------------------------------------------------------------------------- */
    /*                                  VARIABLES                                 */
    /* -------------------------------------------------------------------------- */

    uint256 private constant BASIS_POINTS = 1e12;

    address private constant WETH = 0x82aF49447D8a07e3bd95BD0d56f35241523fBab1;

    IUnderlyingVault public stableVault;

    ILeverageViewer public viewer;
    IjGlvRouter private jGlvRouter;

    IERC20 public stable;

    uint256 public stableDebt;
    uint256 public pendingjGlv;

    /// @notice Incentives
    address public incentiveReceiver;
    uint256 public protocolRate;
    uint256 public jonesRate;

    LeverageConfig public leverageConfig;

    // 1 = Idle
    // 2 = Withdrawal
    // 3 = Leverage down
    // 4 = Harvest
    // 5 = Liquidate
    // 6 = Payback

    uint8 public ongoingAction;

    ///@notice Callback data
    CallbackData public callbackData;

    /* -------------------------------------------------------------------------- */
    /*                                 INITIALIZE                                 */
    /* -------------------------------------------------------------------------- */

    function initialize(
        LeverageConfig memory _leverageConfig,
        address _viewer,
        address _stableVault,
        address _incentiveReceiver,
        uint256 _protocolRate,
        uint256 _jonesRate
    ) external initializer {
        __Governable_init(msg.sender);

        viewer = ILeverageViewer(_viewer);
        jGlvRouter = IjGlvRouter(viewer.jGlvRouter());

        stableVault = IUnderlyingVault(_stableVault);

        stable = stableVault.underlying();

        incentiveReceiver = _incentiveReceiver;
        if (_protocolRate + jonesRate > BASIS_POINTS) {
            revert InvalidParams();
        }
        protocolRate = _protocolRate;
        jonesRate = _jonesRate;

        ongoingAction = 1;

        leverageConfig = _leverageConfig;

        stable.approve(address(jGlvRouter), type(uint256).max);
        stable.approve(_stableVault, type(uint256).max);
    }

    /* -------------------------------------------------------------------------- */
    /*                                  OPERATOR                                  */
    /* -------------------------------------------------------------------------- */

    /**
     * @notice Enforce Payback to stable vault
     * @param amount Amount to pay back
     * @param enforceData Extra data to enforce payback
     * @return gmx retention used in the payback
     */
    function payBack(uint256 amount, bytes calldata enforceData)
        external
        payable
        override(IPayBack)
        onlyOperator
        returns (uint256)
    {
        viewer.ongoingOperationCheck();

        ///@notice Decode Data
        IjGlvRouter.WithdrawalParams memory params = abi.decode(enforceData, (IjGlvRouter.WithdrawalParams));

        return _payBack(amount, false, params);
    }

    function onGLVDeposit(uint256 _assets) external payable onlyOperator {
        viewer.ongoingOperationCheck();

        uint256 stablesToBorrow;

        if (viewer.getLeverage() <= leverageConfig.target) {
            stablesToBorrow = _assets.mulDivDown(leverageConfig.target - BASIS_POINTS, BASIS_POINTS);

            uint256 availableForBorrowing = stableVault.borrowableAmount(address(this));
            if (availableForBorrowing < stablesToBorrow) {
                stablesToBorrow = availableForBorrowing;
            }
            if (stablesToBorrow > 0) {
                stableVault.borrow(stablesToBorrow);
                emit BorrowStable(stablesToBorrow);

                stableDebt = stableDebt + stablesToBorrow;
            }
        }

        jGlvRouter.deposit(stablesToBorrow + _assets, address(this));

        emit StrategyDeposit(_assets, stablesToBorrow);
    }

    function onGlvWithdrawal(
        uint8 _action,
        uint256 _shares,
        uint256 _jGlvToRedeem,
        address _receiver,
        IjGlvRouter.WithdrawalParams memory _params
    ) external payable onlyOperator {
        viewer.ongoingOperationCheck();

        uint256 underlying = viewer.getUnderlyingAssets();
        uint256 bp = BASIS_POINTS;
        uint256 currentLev;

        if (underlying == 0) {
            if (stableDebt > 0) {
                revert UnWind();
            }
            currentLev = bp;
        }

        if (stableDebt == 0) {
            currentLev = bp;
        }

        uint256 currentBalance = viewer.getTotalStrategyAssets();

        currentLev = ((currentBalance * bp) / underlying);

        uint256 maxLev = leverageConfig.max;

        uint256 protocolRetention = _jGlvToRedeem.mulDivDown(protocolRate, BASIS_POINTS);

        _jGlvToRedeem = _jGlvToRedeem - protocolRetention;
        uint256 levjGlvToRedeem;

        if (currentLev > maxLev) {
            levjGlvToRedeem = _jGlvToRedeem.mulDivDown(currentLev - maxLev, bp);
        }

        callbackData = CallbackData({
            shares: _shares,
            jGlvToRedeem: _jGlvToRedeem,
            levjGlvToRedeem: levjGlvToRedeem,
            receiver: _receiver,
            underlyingAssets: underlying,
            totalAssets: currentBalance
        });

        ongoingAction = 2;

        pendingjGlv = _jGlvToRedeem + levjGlvToRedeem;

        jGlvRouter.withdrawal{value: msg.value}(_jGlvToRedeem + levjGlvToRedeem, address(this), address(this), _params);

        emit StrategyWithdrawalCreated(_jGlvToRedeem, levjGlvToRedeem, protocolRetention, msg.value);
    }

    function withdrawalCallback(uint256 _jGlvShares, uint256 _usdc) external {
        if (msg.sender != address(viewer.jGlvStrategy())) {
            revert InvalidCaller();
        }

        if (ongoingAction == 1) {
            revert IdleAction();
        }

        pendingjGlv = pendingjGlv - _jGlvShares;

        CallbackData memory callback = callbackData;

        if (ongoingAction == 2) {
            if (callback.levjGlvToRedeem > 0) {
                uint256 toPayBack =
                    _usdc.mulDivDown(callback.levjGlvToRedeem, callbackData.jGlvToRedeem + callbackData.levjGlvToRedeem);
                _repayStable(toPayBack);
                _usdc = _usdc - toPayBack;
            }

            uint256 jonesRetention;

            if (protocolRate > 0 && jonesRate > 0) {
                jonesRetention =
                    _usdc.mulDivDown(BASIS_POINTS, BASIS_POINTS - protocolRate).mulDivDown(jonesRate, BASIS_POINTS);
            } else if (jonesRate > 0) {
                jonesRetention = _usdc.mulDivDown(jonesRate, BASIS_POINTS);
            }

            address _incentiveReceiver = incentiveReceiver;

            if (_incentiveReceiver != address(0) && jonesRetention > 0) {
                stable.transfer(_incentiveReceiver, jonesRetention);
                emit Retention(_incentiveReceiver, _usdc, _usdc - jonesRetention);
                _usdc = _usdc - jonesRetention;
            }

            /// @notice burn shares
            viewer.wjGlv().burn(address(this), callback.shares);

            stable.transfer(callback.receiver, _usdc);

            emit SuccessfulWithdrawal(callback.receiver, callback.shares, callback.jGlvToRedeem, _usdc);
        } else if (ongoingAction == 4) {
            address _incentiveReceiver = incentiveReceiver;
            uint256 jonesRewards;

            if (_incentiveReceiver != address(0)) {
                jonesRewards = _usdc.mulDivDown(callback.levjGlvToRedeem, BASIS_POINTS);
                stable.transfer(_incentiveReceiver, jonesRewards);
            }

            uint256 jusdcRewards = _usdc - jonesRewards;

            stableVault.receiveRewards(jusdcRewards);

            emit Rewards(
                jusdcRewards, jonesRewards, callback.jGlvToRedeem, callback.underlyingAssets, callback.totalAssets
            );
        } else if (ongoingAction == 6) {
            _usdc = stable.balanceOf(address(this));

            stableVault.payBack(_usdc, callback.levjGlvToRedeem);

            stableDebt = stableDebt > _usdc ? stableDebt - _usdc : 0;

            stable.transfer(incentiveReceiver, callback.levjGlvToRedeem);

            if (callback.receiver != address(0)) {
                IEnforcePayBackCallback(callback.receiver).payBackCallback(callback.levjGlvToRedeem);
            }

            emit Payback(_usdc, callback.shares, callback.levjGlvToRedeem);
        } else {
            _repayStable(_usdc);
            if (ongoingAction == 3) {
                emit LeverageDown(
                    stableDebt,
                    callback.totalAssets.mulDivDown(BASIS_POINTS, callback.underlyingAssets),
                    viewer.getLeverage()
                );
            } else {
                emit Liquidate(stableDebt);
                ongoingAction = type(uint8).max;
                return;
            }
        }

        callbackData = CallbackData({
            shares: 0,
            jGlvToRedeem: 0,
            levjGlvToRedeem: 0,
            receiver: address(0),
            underlyingAssets: 0,
            totalAssets: 0
        });

        ongoingAction = 1;
    }

    /* -------------------------------------------------------------------------- */
    /*                                     VIEW                                   */
    /* -------------------------------------------------------------------------- */

    function retentionRefund(uint256 amount, bytes calldata enforceData)
        external
        view
        override(IPayBack, ILeverageStrategy)
        returns (uint256)
    {
        ///@notice Decode Data
        IjGlvRouter.WithdrawalParams memory params = abi.decode(enforceData, (IjGlvRouter.WithdrawalParams));

        uint256 length = params.executionFee.length;

        uint256 incentives;

        for (uint256 i; i < length;) {
            incentives = incentives + params.executionFee[i];

            unchecked {
                ++i;
            }
        }

        incentives = incentives.mulDivDown(viewer.tokenPrice(WETH), 1e20); // USD
        return incentives.mulDivDown(1e8, viewer.tokenPrice(address(stable))); // USDC
    }

    /* -------------------------------------------------------------------------- */
    /*                                   KEEEPR                                   */
    /* -------------------------------------------------------------------------- */

    /**
     * @notice Harvest rewards. Action 4
     */
    function harvest(uint256 redeemPercentage, uint256 jonesPercentage, IjGlvRouter.WithdrawalParams memory params)
        external
        payable
        onlyKeeper
    {
        viewer.ongoingOperationCheck();

        address thisAddress = address(this);

        uint256 jGlvToRedeem = viewer.jGlvBalanceOf(thisAddress).mulDivDown(redeemPercentage, BASIS_POINTS);

        callbackData = CallbackData({
            shares: 0,
            jGlvToRedeem: jGlvToRedeem,
            levjGlvToRedeem: jonesPercentage,
            receiver: address(0),
            underlyingAssets: viewer.getUnderlyingAssets(),
            totalAssets: viewer.getTotalStrategyAssets()
        });

        ongoingAction = 4;

        jGlvRouter.withdrawal{value: msg.value}(jGlvToRedeem, thisAddress, thisAddress, params);
    }

    /**
     * @notice Sell GLV tokens to get USDC in case to be needed for a withdrawal in jUSDC vault. Action 6
     */
    function keeperPayBack(uint256 amount, IjGlvRouter.WithdrawalParams memory params)
        external
        payable
        onlyKeeper
        returns (uint256)
    {
        viewer.ongoingOperationCheck();
        return _payBack(amount, true, params);
    }

    /**
     * @notice Deleverage & pay stable debt. Action 5
     */
    function unwind(IjGlvRouter.WithdrawalParams memory params) external payable onlyGovernorOrKeeper {
        viewer.ongoingOperationCheck();

        _setLeverageConfig(LeverageConfig(BASIS_POINTS + 1, BASIS_POINTS, BASIS_POINTS + 2));

        if (stableDebt == 0) {
            return;
        }

        address thisAddress = address(this);

        uint256 jGlvToRedeem = viewer.jGlvBalanceOf(thisAddress);

        ongoingAction = 5;

        jGlvRouter.withdrawal{value: msg.value}(jGlvToRedeem, thisAddress, thisAddress, params);
    }

    /**
     * @notice Using by the bot to leverage Up if is needed. Action 4
     */
    function leverageUp(uint256 newLoan) external payable onlyKeeper {
        viewer.ongoingOperationCheck();

        LevVars memory vars;

        vars.thisAddress = address(this);
        vars.availableForBorrowing = stableVault.borrowableAmount(vars.thisAddress);

        if (vars.availableForBorrowing == 0) {
            return;
        }

        vars.oldLeverage = viewer.getLeverage();

        vars.stablesInStrategy = stable.balanceOf(vars.thisAddress);

        vars.stablesToBorrow = newLoan > vars.stablesInStrategy ? newLoan - vars.stablesInStrategy : 0;

        if (vars.availableForBorrowing < vars.stablesToBorrow) {
            revert NotEnoughAmount();
        }

        if (vars.stablesToBorrow > 0) {
            stableVault.borrow(vars.stablesToBorrow);
            emit BorrowStable(vars.stablesToBorrow);

            stableDebt = stableDebt + vars.stablesToBorrow;
        }

        jGlvRouter.deposit(vars.stablesToBorrow, vars.thisAddress);

        vars.newLeverage = viewer.getLeverage();

        if (vars.newLeverage < vars.oldLeverage) {
            revert UnderLeveraged();
        }

        if (vars.newLeverage > leverageConfig.max) {
            revert OverLeveraged();
        }

        emit LeverageUp(stableDebt, vars.oldLeverage, vars.newLeverage);
    }

    /**
     * @notice Using by the bot to leverage Down if is needed. Action 3
     */
    function leverageDown(uint256 redeemPercentage, IjGlvRouter.WithdrawalParams memory params)
        external
        payable
        onlyKeeper
    {
        viewer.ongoingOperationCheck();

        address thisAddress = address(this);

        uint256 jGlvToRedeem = viewer.jGlvBalanceOf(thisAddress).mulDivDown(redeemPercentage, BASIS_POINTS);

        uint256 stablesToPayBack = viewer.jGlvViewer().previewRedeem(jGlvToRedeem);

        uint256 _stableDebt = stableDebt;

        uint256 underlyingAssets = viewer.getUnderlyingAssets();
        uint256 totalAssets = viewer.getTotalStrategyAssets();

        if (stablesToPayBack > _stableDebt) {
            revert OverPayDebt();
        }

        if (underlyingAssets == 0) {
            if (_stableDebt > 0) {
                revert UnWind();
            }
            return;
        }

        uint256 oldLeverage = totalAssets.mulDivDown(BASIS_POINTS, underlyingAssets);

        uint256 newLeverage;

        if (_stableDebt - stablesToPayBack == 0) {
            newLeverage = BASIS_POINTS;
        } else {
            newLeverage = viewer.getLeverageAfterPayBack(jGlvToRedeem, stablesToPayBack);
        }

        if (newLeverage > oldLeverage) {
            revert OverLeveraged();
        }

        if (newLeverage < leverageConfig.min) {
            revert UnderLeveraged();
        }

        callbackData = CallbackData({
            shares: 0,
            jGlvToRedeem: jGlvToRedeem,
            levjGlvToRedeem: 0,
            receiver: address(0),
            underlyingAssets: underlyingAssets,
            totalAssets: totalAssets
        });

        ongoingAction = 3;

        jGlvRouter.withdrawal{value: msg.value}(jGlvToRedeem, thisAddress, thisAddress, params);
    }

    /* -------------------------------------------------------------------------- */
    /*                                  GOVERNOR                                  */
    /* -------------------------------------------------------------------------- */

    /**
     * @notice Set Leverage Configuration
     * @dev Precision is based on 1e12 as 1x leverage
     * @param _target Target leverage
     * @param _min Min Leverage
     * @param _max Max Leverage
     */
    function setLeverageConfig(uint256 _target, uint256 _min, uint256 _max) public onlyGovernor {
        _setLeverageConfig(LeverageConfig(_target, _min, _max));
        emit SetLeverageConfig(_target, _min, _max);
    }

    /**
     * @notice Approve token to be spend
     */
    function forceApproval(address token, address spender, uint256 amount) external onlyGovernor {
        IERC20(token).approve(spender, amount);
    }

    /**
     * @notice Set new stable vault
     * @param _stableVault Stable vault address
     */
    function updateStableVault(address _stableVault) external onlyGovernor {
        viewer.ongoingOperationCheck();

        stable.approve(address(jGlvRouter), 0);
        stable.approve(address(stableVault), 0);
        stableVault = IUnderlyingVault(_stableVault);
        stable = stableVault.underlying();
        stable.approve(address(jGlvRouter), type(uint256).max);
        stable.approve(_stableVault, type(uint256).max);
    }

    /**
     * @notice Set new internal contracts
     * @param _viewer Leverage Viewer
     */
    function setInternalContracts(address _viewer) external onlyGovernor {
        viewer.ongoingOperationCheck();

        stable.approve(address(jGlvRouter), 0);
        viewer = ILeverageViewer(_viewer);
        jGlvRouter = IjGlvRouter(viewer.jGlvRouter());
        stable.approve(address(jGlvRouter), type(uint256).max);
    }

    /**
     * @notice Update Incentive Variables
     * @param _incentiveReceiver incentive receiver address
     */
    function updateIncentives(address _incentiveReceiver, uint256 _protocolRate, uint256 _jonesRate)
        external
        onlyGovernor
    {
        incentiveReceiver = _incentiveReceiver;
        if (_protocolRate + _jonesRate > BASIS_POINTS) {
            revert InvalidParams();
        }
        protocolRate = _protocolRate;
        jonesRate = _jonesRate;
    }

    /**
     * @notice Enforce action
     * @param _action action
     */
    function enforceAction(uint8 _action) external onlyGovernorOrOperator {
        ongoingAction = _action;
    }

    /**
     * @notice Moves assets from the strategy to `_to`
     * @param _assets An array of IERC20 compatible tokens to move out from the strategy
     * @param _withdrawNative `true` if we want to move the native asset from the strategy
     */
    function emergencyWithdraw(address _to, address[] memory _assets, bool _withdrawNative) external onlyGovernor {
        uint256 assetsLength = _assets.length;
        for (uint256 i = 0; i < assetsLength;) {
            IERC20 asset_ = IERC20(_assets[i]);
            uint256 assetBalance = asset_.balanceOf(address(this));

            if (assetBalance > 0) {
                // Transfer the ERC20 tokens
                asset_.transfer(_to, assetBalance);
            }

            unchecked {
                ++i;
            }
        }

        uint256 nativeBalance = address(this).balance;

        // Nothing else to do
        if (_withdrawNative && nativeBalance > 0) {
            // Transfer the native currency
            (bool sent,) = payable(_to).call{value: nativeBalance}("");
            if (!sent) {
                revert FailSendETH();
            }
        }

        emit EmergencyWithdrawal(msg.sender, _to, _assets, _withdrawNative ? nativeBalance : 0);
    }

    /* -------------------------------------------------------------------------- */
    /*                                  PRIVATE                                   */
    /* -------------------------------------------------------------------------- */

    function _payBack(uint256 amount, bool keeper, IjGlvRouter.WithdrawalParams memory params)
        private
        returns (uint256)
    {
        PayBackVars memory vars;

        vars.thisAddress = address(this);
        vars.strategyStables = stable.balanceOf(vars.thisAddress);
        vars.expectedStables = amount > vars.strategyStables ? amount - vars.strategyStables : 0;

        if (vars.expectedStables > 0) {
            if (ongoingAction != 1) {
                revert OngoingAction();
            }

            vars.length = params.executionFee.length;

            for (uint256 i; i < vars.length;) {
                vars.gmxIncentive = vars.gmxIncentive + params.executionFee[i];

                unchecked {
                    ++i;
                }
            }

            vars.shares = viewer.getjGlvToPayback(vars.expectedStables);

            vars.incentives = vars.gmxIncentive.mulDivDown(viewer.tokenPrice(WETH), 1e20); // USD
            vars.incentives = vars.incentives.mulDivDown(1e8, viewer.tokenPrice(address(stable))); // USDC

            callbackData = CallbackData({
                shares: amount,
                jGlvToRedeem: vars.shares,
                levjGlvToRedeem: vars.incentives,
                receiver: keeper ? address(0) : msg.sender,
                underlyingAssets: 0,
                totalAssets: 0
            });

            ongoingAction = 6;

            if (msg.value >= vars.gmxIncentive && msg.value > 0) {
                jGlvRouter.withdrawal{value: vars.gmxIncentive}(vars.shares, vars.thisAddress, vars.thisAddress, params);

                if (msg.value > vars.gmxIncentive) {
                    (bool sent,) = payable(msg.sender).call{value: msg.value - vars.gmxIncentive}("");
                    if (!sent) {
                        revert FailSendETH();
                    }
                }
            } else {
                revert NotEnoughAmount();
            }
        } else {
            if (amount > 0) {
                _repayStable(amount);
                return 0;
            } else {
                return 0;
            }
        }

        return vars.incentives;
    }

    function _repayStable(uint256 _amount) private returns (uint256) {
        uint256 amountToRepay = _amount > stableDebt ? stableDebt : _amount;

        stableVault.payBack(amountToRepay, 0);

        uint256 updatedAmount = stableDebt - amountToRepay;

        stableDebt = updatedAmount;

        emit Payback(amountToRepay, 0, 0);

        return updatedAmount;
    }

    function _setLeverageConfig(LeverageConfig memory _config) private {
        if (
            _config.min >= _config.max || _config.min >= _config.target || _config.max <= _config.target
                || _config.min < BASIS_POINTS
        ) {
            revert InvalidLevConf();
        }

        leverageConfig = _config;
    }
}
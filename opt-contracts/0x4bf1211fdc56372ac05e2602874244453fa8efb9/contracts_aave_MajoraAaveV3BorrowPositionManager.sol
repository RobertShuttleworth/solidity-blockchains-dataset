// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import {IERC20} from "./openzeppelin_contracts_token_ERC20_IERC20.sol";
import {SafeERC20} from "./openzeppelin_contracts_token_ERC20_utils_SafeERC20.sol";

import {IMajoraPortal} from "./majora-finance_portal_contracts_interfaces_IMajoraPortal.sol";
import {IMajoraVault} from "./majora-finance_core_contracts_interfaces_IMajoraVault.sol";

import {IMajoraCommonBlock} from "./majora-finance_libraries_contracts_interfaces_IMajoraCommonBlock.sol";
import {DataTypes} from "./majora-finance_libraries_contracts_DataTypes.sol";
import {LibOracleState} from "./majora-finance_libraries_contracts_LibOracleState.sol";

import {IPool} from "./aave_core-v3_contracts_interfaces_IPool.sol";
import {IAaveOracle} from "./aave_core-v3_contracts_interfaces_IAaveOracle.sol";
import {DataTypes as AaveDataType} from "./aave_core-v3_contracts_protocol_libraries_types_DataTypes.sol";
import {PercentageMath} from "./aave_core-v3_contracts_protocol_libraries_math_PercentageMath.sol";
import {WadRayMath} from "./aave_core-v3_contracts_protocol_libraries_math_WadRayMath.sol";
import {ReserveConfiguration} from "./aave_core-v3_contracts_protocol_libraries_configuration_ReserveConfiguration.sol";

import {IMajoraPositionManager} from "./contracts_interfaces_IMajoraPositionManager.sol";
import {MajoraAaveV3PositionManagerCommons} from "./contracts_aave_MajoraAaveV3PositionManagerCommons.sol";
import {IMajoraAaveV3BorrowPositionManager} from "./contracts_aave_interfaces_IMajoraAaveV3BorrowPositionManager.sol";
import {IMajoraOperatorProxy} from "./contracts_interfaces_IMajoraOperatorProxy.sol";
import {IMajoraAddressesProvider} from "./majora-finance_access-manager_contracts_interfaces_IMajoraAddressesProvider.sol";

/**
 * @title Majora Aave V3 Borrow Position Manager
 * @author Majora Development Association
 * @notice This contract manages positions within the Aave V3 protocol, 
 * enabling Majoraies that involve leveraging, unleveraging, and rebalancing of assets. 
 * It interacts with Aave's lending pool to supply collateral, borrow assets, and manage debt positions, 
 * while also utilizing a portal for asset swaps necessary for Majoray execution. 
 * The contract supports operations such as initializing a position with specific parameters, 
 * leveraging up or down a position, and rebalancing based on health factor thresholds.
 * @dev The contract uses the SafeERC20 library for safe token transfers and the WadRayMath library for precise arithmetic operations. 
 * It integrates with Aave's lending pool and oracle for managing and valuing the positions. 
 * The contract is designed to be operated by an owner, who can execute Majoraies, and an operator, who can rebalance positions. 
 * It leverages flash loans for non-custodial leverage operations and integrates with a swap portal for executing asset swaps.
 */
contract MajoraAaveV3BorrowPositionManager is IMajoraAaveV3BorrowPositionManager, MajoraAaveV3PositionManagerCommons {
    using SafeERC20 for IERC20;
    using WadRayMath for uint256;
    using PercentageMath for uint256;
    using ReserveConfiguration for AaveDataType.ReserveConfigurationMap;
    using LibOracleState for DataTypes.OracleState;

    constructor(
        address _pool,
        address _oracle,
        address _addressProvider
    ) MajoraAaveV3PositionManagerCommons(_pool, _oracle, _addressProvider) {}

    /**
     * @notice Retrieves the borrowing status of the current position.
     * @param _withSpecificAvailableTokenForRepay Indicates if a specific token amount is available for repayment.
     * @param _availableTokenForRepay The amount of token available for repayment if `_withSpecificAvailableTokenForRepay` is true.
     * @return state The borrowing status of the current position as a `BorrowStatus` struct.
     */
    function status(
        bool _withSpecificAvailableTokenForRepay,
        uint256 _availableTokenForRepay,
        uint256 _percent
    ) external view returns (BorrowStatus memory state) {
        (, , , , , uint256 healthFactor) = _getUserAccountData(address(this));

        if (healthFactor == type(uint256).max) {
            state.empty = true;
            if(_position.debt.token.balanceOf(address(this)) > 0 || _position.collateral.token.balanceOf(address(this)) > 0)  {
                state.hasDust = true;
            }
            return state;
        }

        state.healthFactor = healthFactor;
        state.healthFactorDesired = _position.healthfactor.desired;
        state.toRebalance = healthFactor < _position.healthfactor.min || healthFactor > _position.healthfactor.max;

        uint256 availableTokenForRepay;
        if (_withSpecificAvailableTokenForRepay) {
            availableTokenForRepay = _availableTokenForRepay;
        } else {
            availableTokenForRepay = _position.debt.token.balanceOf(address(this));
        }

        state.debtAmount = _position.debt.debtToken.balanceOf(address(this));
        state.collateralAmount = _position.collateral.aToken.balanceOf(address(this));
        state.positionDeltaIsPositive = availableTokenForRepay >= (state.debtAmount * _percent / 10000);
        state.availableTokenForRepay = availableTokenForRepay;

        if (state.positionDeltaIsPositive) {
            state.deltaAmount = availableTokenForRepay - (state.debtAmount * _percent / 10000);
        } else {
            state.deltaAmount = (state.debtAmount * _percent / 10000) - availableTokenForRepay;
        }

        if (state.toRebalance) {
            state.rebalanceAmountToRepay = _getRebalanceRepayAmount();
        }
    }

    /**
     * @notice Calculates the amount that can be borrowed for a given collateral amount.
     * @dev This function computes the borrow amount based on the collateral's value, loan-to-value ratio, and the desired health factor.
     * @param _collateral The amount of collateral to be deposited.
     * @return borrowAmount The maximum amount that can be borrowed.
     */
    function borrowAmountFor(uint256 _collateral) external view returns (uint256) {
        address[] memory assets = new address[](2);
        assets[0] = address(_position.collateral.token);
        assets[1] = address(_position.debt.token);
        uint256[] memory prices = oracle.getAssetsPrices(assets);

        /**
         * Fetch Aave user account data
         */
        (uint256 totalCollateralBase, uint256 totalDebtBase,,,,) = _getUserAccountData(address(this));

        uint256 collateralBase = totalCollateralBase + ((_collateral * prices[0]) / 10 ** _position.collateral.decimals);
        
        
        uint256 toBorrowBase = (collateralBase.percentMul(_position.collateral.lts) * 1e18) / _position.healthfactor.desired;
        if(toBorrowBase <= totalDebtBase) return 0;
        
        uint256 borrowAmount = ((toBorrowBase - totalDebtBase) * 10 ** _position.debt.decimals) / prices[1];

        return borrowAmount;
    }

    /**
     * @notice Calculates the collateral amount returned after a specified debt amount is repaid.
     * @dev This function computes the returned collateral amount after repaying a portion of the debt,
     * taking into account the current prices of the collateral and debt assets.
     * @param _availableAssets The amount of debt to be repaid.
     * @return collateralAmount The amount of collateral returned after the debt repayment.
     */
    function returnedAmountAfterRepay(uint256 _availableAssets, uint256 _percent) external view returns (uint256) {
        address[] memory assets = new address[](2);
        assets[0] = address(_position.collateral.token);
        assets[1] = address(_position.debt.token);
        uint256[] memory prices = oracle.getAssetsPrices(assets);
        (uint256 totalCollateralBase, uint256 totalDebtBase, , , , ) = _getUserAccountData(address(this));

        uint256 availableAssetBase = (_availableAssets * prices[1]) / 10 ** _position.debt.decimals;
        uint256 theoricalRepayBase = totalDebtBase * _percent / 10000;
        uint256 collateralBaseReturned = (totalCollateralBase * _percent) / 10000;

        if(availableAssetBase > theoricalRepayBase) {
            //repay all and convert (_availableAssets - theoricalRepay) to collateral value
            collateralBaseReturned += (availableAssetBase - theoricalRepayBase);
        } else {
            //convert missing repay amount from collateral
            collateralBaseReturned -= (theoricalRepayBase - availableAssetBase);
        }

        uint256 collateralAmount = (collateralBaseReturned * 10 ** _position.collateral.decimals) / prices[0];
        return collateralAmount;
    }

    /**
     * @notice Initiates a borrowing operation to adjust the position's health factor.
     * @dev This function allows for borrowing additional debt based on the provided collateral amount. It ensures that the operation adheres to the position's desired health factor constraints.
     * @param _addCollateralAmount The amount of additional collateral to be deposited before borrowing.
     */
    function borrow(uint256 _addCollateralAmount) external onlyOwner {
        IERC20 collateral = _position.collateral.token;

        /**
         * Transfer deposited collateral
         */
        if (_addCollateralAmount > 0) {
            collateral.safeTransferFrom(msg.sender, address(this), _addCollateralAmount);
        }

        /**
         * Deposit all liquidity available
         */
        {
            uint256 collateralBalance = collateral.balanceOf(address(this));
            if (collateralBalance > 0) {
                _supply(address(collateral), collateralBalance, address(this), REFERAL);
            }
        }

        uint256 borrowed = _borrowToMatchHealthfactor();
        emit BorrowExecuted(borrowed);
    }

    /**
     * @notice Repays the borrowed asset to reduce or close the position.
     * @dev This function repays the debt of the position, potentially using a dynamic swap if the debt token balance is insufficient. It ensures the position's health factor is adjusted appropriately.
     * @param _dynamicParams Encoded dynamic parameters for swap operations, if needed.
     */
    function repay(bytes memory _dynamicParams, uint256 _percent) external onlyOwner {
        IERC20 collateral = _position.collateral.token;
        bool dynParamsUsed = false;
        

        /**
         * Pre compute theorical targets
         */
        (uint256 collateralTarget, uint256 debtTarget) = _getRepayCollateralAndDebtTarget(_percent);
        uint256 amountToRepay = _position.debt.debtToken.balanceOf(address(this)) - debtTarget;
        uint256 debtTokenBalance = _position.debt.token.balanceOf(address(this));
        
        /**
         * If the amount to repay is not covered by the debt token
         * - estimate the collateral amount to sell
         * - withdraw the collateral
         * - sell the collateral for debt token
         */
        if (amountToRepay > debtTokenBalance) {
            if (_dynamicParams.length > 0) {
                DataTypes.DynamicSwapData memory params = abi.decode(_dynamicParams, (DataTypes.DynamicSwapData));
                _repay(address(_position.debt.token), debtTokenBalance, _position.debt.debtType, address(this));
                amountToRepay -= debtTokenBalance;

                _withdraw(address(collateral), params.amount, address(this));
                _swap(params);

                dynParamsUsed = true;
                uint256 newDebtTokenBalance = _position.debt.token.balanceOf(address(this));

                if (amountToRepay > newDebtTokenBalance) {
                    revert RepayNotCoveredWithSwap();
                } else if(newDebtTokenBalance > amountToRepay) {
                    _position.debt.token.safeTransfer(owner, newDebtTokenBalance - amountToRepay);
                }
            } else {
                revert DynamicParametersNeeded();
            }
        }

        /**
         * Execute repay
         */
        _repay(address(_position.debt.token), amountToRepay, _position.debt.debtType, address(this));

        /**
         * If there is more debt token balance than repaid amount
         * swap remaining tokens to collateral token
         */
        if (!dynParamsUsed && _dynamicParams.length > 0 && debtTokenBalance > amountToRepay) {
            DataTypes.DynamicSwapData memory params = abi.decode(_dynamicParams, (DataTypes.DynamicSwapData));
            _swap(params);
        }

        uint256 amountToWithdraw = _position.collateral.aToken.balanceOf(address(this)) - collateralTarget;

        _withdraw(address(_position.collateral.token), amountToWithdraw, address(this));
        _position.collateral.token.safeTransfer(msg.sender, _position.collateral.token.balanceOf(address(this)));

        emit RepayExecuted(_percent);
    }

    /**
     * @notice Rebalances the position based on the provided parameters.
     * @dev This function decides whether to leverage or unleverage the position based on the rebalance parameters.
     * If the position is in leverage mode and the health factor is below the desired threshold, it leverages up.
     * If the health factor is above the desired threshold, it unleverages.
     * For positions not in leverage mode, it either borrows more or repays part of the debt based on the health factor.
     * Additionally, it can execute partial Majoray enter or exit based on the vault contract status and provided parameters.
     * @param params The rebalance parameters including swap data and dynamic parameters for partial Majoray execution.
     */
    function rebalance(RebalanceData memory params) external onlyOperatorProxy {
        /**
         * Steps resume
         * if rebalance positive (more borrow needed)
         *      - compute amount to borrow
         *
         * if rebalance leverage (repay needed)
         *      call leverage
         */
        bool _ownerIsMajoraVault = ownerIsMajoraVault;
        if (params.healthfactorIsOverMaximum) {
            _borrowToMatchHealthfactor();

            /**
             * Execute partial Majoray enter for index > current index
             */
            if (_ownerIsMajoraVault) {
                IMajoraVault(owner).partialStrategyExecution(
                    true,
                    address(0),
                    params.partialEnterExecution.from,
                    params.partialEnterExecution.to,
                    params.partialEnterExecution.dynParamsIndex,
                    params.partialEnterExecution.dynParams
                );
            }
        } else {
            /**
             * Execute partial Majoray exit for index > current index
             */
            if (_ownerIsMajoraVault) {
                IMajoraVault(owner).partialStrategyExecution(
                    false,
                    address(_position.debt.token),
                    params.partialExitExecution.from,
                    params.partialExitExecution.to,
                    params.partialExitExecution.dynParamsIndex,
                    params.partialExitExecution.dynParams
                );
            }

            _repayToMatchHealthfactor(params.data);
            _position.debt.token.safeTransfer(owner, _position.debt.token.balanceOf(address(this)));

            /**
             * Execute partial Majoray enter for index > current index
             */
            if (_ownerIsMajoraVault) {
                IMajoraVault(owner).partialStrategyExecution(
                    true,
                    address(0),
                    params.partialEnterExecution.from,
                    params.partialEnterExecution.to,
                    params.partialEnterExecution.dynParamsIndex,
                    params.partialEnterExecution.dynParams
                );
            }
        }

        emit RebalanceExecuted();
    }

    function _getRebalanceRepayAmount() internal view returns (uint256) {
        (
            uint256 totalCollateralBase,
            uint256 totalDebtBase,
            ,
            uint256 currentLiquidationThreshold,
            ,

        ) = _getUserAccountData(address(this));

        uint256 assetBaseWeiPrice = oracle.getAssetPrice(address(_position.debt.token));
        uint256 desiredBorrowBase = (totalCollateralBase.percentMul(currentLiquidationThreshold) * 1e18) /
            _position.healthfactor.desired;

        uint256 amountToRepayBase;
        if (desiredBorrowBase < totalDebtBase) {
            amountToRepayBase = totalDebtBase - desiredBorrowBase;
            return (amountToRepayBase * 10 ** _position.debt.decimals) / assetBaseWeiPrice;
        } else {
            return 0;
        }
    }

    function _getBorrowAmountToMatchHealthfactor() internal view returns (uint256) {
        /**
         * Fetch Aave user account data
         */
        (
            uint256 totalCollateralBase,
            uint256 totalDebtBase,
            ,
            uint256 currentLiquidationThreshold,
            ,
            uint256 healthFactor
        ) = _getUserAccountData(address(this));

        /**
         * If health factor match with parameters: skip
         */
        if (healthFactor <= _position.healthfactor.desired) {
            return 0;
        }

        /**
         * if HF is over maximum
         * Compute amount to borrow to match with parameters
         * formula process:
         *
         * healthfactor = ((totalCollateralInBaseCurrency * currentLiquidationThreshold) / 10000) / totalDebtBase
         * healthfactorDesired = ((totalCollateralInBaseCurrency * currentLiquidationThreshold) / 10000) / totalDebtDesired
         *
         *
         * totalDebtBaseDesired = (totalCollateralInBaseCurrency * currentLiquidationThreshold) / 10000) / hfDesired
         *
         * borrowAmount = totalDebtBaseDesired - totalDebtBase
         * borrowAmount = ((totalCollateralInBaseCurrency * currentLiquidationThreshold) / 10000) / hfDesired) - totalDebtBase
         */
        uint256 debtBaseWeiPrice = oracle.getAssetPrice(address(_position.debt.token));
        uint256 toBorrowBase = ((totalCollateralBase.percentMul(currentLiquidationThreshold) * 1e18) /
            _position.healthfactor.desired) - totalDebtBase;
        uint256 borrowAmount = (toBorrowBase * 10 ** _position.debt.decimals) / debtBaseWeiPrice;

        return borrowAmount;
    }

    function _borrowToMatchHealthfactor() internal returns (uint256) {
        uint256 borrowAmount = _getBorrowAmountToMatchHealthfactor();
        if (borrowAmount > 0) {
            _borrow(
                address(_position.debt.token), //token to borrow
                borrowAmount, //amount to borrow
                _position.debt.debtType, //variable interest rate
                REFERAL, //referal code
                address(this) //onBehalf
            );

            _position.debt.token.safeTransfer(owner, borrowAmount);
        }

        return borrowAmount;
    }

    function _getRepayAmountToMatchHealthfactor() internal view returns (uint256) {
        /**
         * Fetch Aave user account data
         */
        (
            uint256 totalCollateralBase,
            uint256 totalDebtBase,
            ,
            uint256 currentLiquidationThreshold,
            ,

        ) = _getUserAccountData(address(this));

        /**
         * if HF is over maximum
         * Compute amount to borrow to match with parameters
         * formula process:
         *
         * healthfactor = ((totalCollateralInBaseCurrency * currentLiquidationThreshold) / 10000) / totalDebtBase
         * healthfactorDesired = ((totalCollateralInBaseCurrency * currentLiquidationThreshold) / 10000) / totalDebtDesired
         *
         *
         * totalDebtBaseDesired = (totalCollateralInBaseCurrency * currentLiquidationThreshold) / 10000) / hfDesired
         *
         * borrowAmount = totalDebtBaseDesired - totalDebtBase
         * borrowAmount = ((totalCollateralInBaseCurrency * currentLiquidationThreshold) / 10000) / hfDesired) - totalDebtBase
         */
        uint256 assetBaseWeiPrice = oracle.getAssetPrice(address(_position.debt.token));
        uint256 totalBorrowBase = (totalCollateralBase.percentMul(currentLiquidationThreshold) * 1e18) /
            _position.healthfactor.desired;
        uint256 amountToRepayBase = totalDebtBase - totalBorrowBase;
        uint256 amountToRepay = (amountToRepayBase * 10 ** _position.debt.decimals) / assetBaseWeiPrice;

        return amountToRepay;
    }

    function _repayToMatchHealthfactor(bytes memory _dynamicParams) internal {
        IERC20 collateral = IERC20(_position.collateral.token);
        uint256 amountToRepay = _getRepayAmountToMatchHealthfactor();
        uint256 debtTokenBalance = _position.debt.token.balanceOf(address(this));

        /**
         * If the amount to repay is not covered by the debt token
         * - estimate the collateral amount to sell
         * - withdraw the collateral
         * - sell the collateral for debt token
         */
        if (_dynamicParams.length > 0 && amountToRepay > debtTokenBalance) {
            DataTypes.DynamicSwapData memory params = abi.decode(_dynamicParams, (DataTypes.DynamicSwapData));
            _withdraw(address(collateral), params.amount, address(this));
            _swap(params);

            uint256 newDebtTokenBalance = _position.debt.token.balanceOf(address(this));

            if (amountToRepay > newDebtTokenBalance) {
                revert RepayNotCoveredWithSwap();
            }
        }

        /**
         * Execute repay
         */
        _repay(address(_position.debt.token), amountToRepay, _position.debt.debtType, address(this));
    }

    function _getRepayCollateralAndDebtTarget(uint256 _percent) internal view returns (uint256, uint256) {
        address[] memory assets = new address[](2);
        assets[0] = address(_position.collateral.token);
        assets[1] = address(_position.debt.token);
        uint256[] memory prices = oracle.getAssetsPrices(assets);

        (uint256 totalCollateralBase, uint256 totalDebtBase,,,,) = _getUserAccountData(address(this));

        uint256 collateralToReturn = totalCollateralBase * _percent / 10000;
        uint256 debtRepaid = totalDebtBase * _percent / 10000;

        return (
            ((totalCollateralBase - collateralToReturn) * 10 ** _position.collateral.decimals) / prices[0],
            ((totalDebtBase - debtRepaid) * 10 ** _position.debt.decimals) / prices[1]
        );
    }
}
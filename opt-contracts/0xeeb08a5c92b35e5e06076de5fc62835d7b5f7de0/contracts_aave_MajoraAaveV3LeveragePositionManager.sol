// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import {IERC20} from "./openzeppelin_contracts_token_ERC20_IERC20.sol";
import {SafeERC20} from "./openzeppelin_contracts_token_ERC20_utils_SafeERC20.sol";

import {DataTypes} from "./majora-finance_libraries_contracts_DataTypes.sol";
import {MajoraAaveV3PositionManagerCommons} from "./contracts_aave_MajoraAaveV3PositionManagerCommons.sol";
import {IMajoraAaveV3LeveragePositionManager} from "./contracts_aave_interfaces_IMajoraAaveV3LeveragePositionManager.sol";

/**
 * @title Majora Aave V3 Leverage Position Manager
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
contract MajoraAaveV3LeveragePositionManager is IMajoraAaveV3LeveragePositionManager, MajoraAaveV3PositionManagerCommons {
    using SafeERC20 for IERC20;

    constructor(
        address _pool, 
        address _oracle,
        address _addressProvider
    ) MajoraAaveV3PositionManagerCommons(_pool, _oracle, _addressProvider) {}

    /**
     * @notice Retrieves the current leverage status of the position.
     * @dev This function returns the leverage status including the health factor, desired health factor, 
     * whether rebalancing is needed, the collateral amount, and the debt amount.
     * @return state The current leverage status of the position.
     */
    function status() external view returns (LeverageStatus memory state) {
        (,,,,, uint256 healthFactor) = _getUserAccountData(address(this));

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
        state.collateralAmount = _position.collateral.aToken.balanceOf(address(this));
        state.debtAmount = _position.debt.debtToken.balanceOf(address(this));
    }

    /**
     * @notice Calculates the collateral amount returned after unleveraging the position.
     * @dev This function computes the returned collateral amount after completely unleveraging the position, 
     * taking into account the current price of the collateral asset.
     * @return collateralAmount The amount of collateral returned after the position is completely unleveraged.
     */
    function returnedAmountAfterUnleverage(uint256 _percent) external view returns (uint256) {
        uint256 collateralPrice = oracle.getAssetPrice(address(_position.collateral.token));

        (uint256 totalCollateralBase, uint256 totalDebtBase,,,,) = _getUserAccountData(address(this));

        uint256 collateralBaseReturned = (totalCollateralBase - totalDebtBase) * _percent / 10000;
        uint256 collateralAmount = (collateralBaseReturned * 10 ** _position.collateral.decimals) / collateralPrice;
        return collateralAmount * 9900 / 10000; // remove unleverage fees: 5 bps flashloan premium / 25 bps portal / 70 bps for swap protocol fee + slippage
    }

    /**
     * @notice Leverages the position by adding collateral and borrowing more debt to increase the position size.
     * @dev This function transfers the specified amount of collateral from the caller, leverages it by borrowing more debt, and then deposits the collateral back into the pool. It ensures that the health factor of the position remains within the desired range after leveraging.
     * @param _addCollateralAmount The amount of additional collateral to add to the position.
     * @param _dynamicParams Encoded dynamic parameters for the leverage operation, including the amount to borrow.
     */
    function leverage(uint256 _addCollateralAmount, bytes calldata _dynamicParams) external onlyOwner {
        /**
         * Transfer deposited collateral
         */
        if (_addCollateralAmount > 0) {
            _position.collateral.token.safeTransferFrom(msg.sender, address(this), _addCollateralAmount);
        }

        _leverage(_dynamicParams);
    }

    function _leverage(bytes memory _dynamicParams) internal {
        /**
         * Steps resume
         * - Calculate the amount to borrow
         * - Execute the flashloan
         *      - Swap borrowed assets to the collateral
         *      - Deposit collateral on pool
         */
        (
            address[] memory assets,
            uint256[] memory amounts,
            uint256[] memory interestRateModes,
            FlashloanData memory params
        ) = _getFlashloanData(10000, address(_position.debt.token), _position.debt.debtType, FlashloanCallbackType.LEVERAGE, _dynamicParams);

        _flashloan(
            address(this), assets, amounts, interestRateModes, address(this), abi.encode(params), REFERAL
        );

        (,,,,, uint256 healthFactor) = _getUserAccountData(address(this));

        if (healthFactor > _position.healthfactor.max || healthFactor < _position.healthfactor.min) {
            revert LeverageHealthfactorNotMatch();
        }
    }

    /**
     * @notice Initiates the process to unleverage the current position.
     * @dev This function calls the internal _unleverage function with the dynamic parameters provided.
     * @param _dynamicParams Encoded dynamic parameters for the unleverage operation.
     */
    function unleverage(bytes memory _dynamicParams, uint256 _percent) external onlyOwner {
        /**
         * Steps resume
         * - Calculate the amount to borrow to unleverage
         * - Execute the flashloan
         *      - Swap collateral flashloaned to repay the debt
         *      - Call repay with repayWithATokens(address asset,uint256 amount,uint256 interestRateMode) function
         *      - withdraw remining collateral
         *      - send collateral to the vault
         */
        (
            address[] memory assets,
            uint256[] memory amounts,
            uint256[] memory interestRateModes,
            FlashloanData memory params
        ) = _getFlashloanData(_percent, address(_position.collateral.token), 0, FlashloanCallbackType.UNLEVERAGE, _dynamicParams);

        _flashloan(
            address(this), assets, amounts, interestRateModes, address(this), abi.encode(params), REFERAL
        );

        _position.collateral.token.safeTransfer(owner, _position.collateral.token.balanceOf(address(this)));
        uint256 remainingDebtToken = _position.debt.token.balanceOf(address(this));
        if(remainingDebtToken > 0)
            _position.debt.token.safeTransfer(owner, remainingDebtToken);

        (uint256 totalCollateralBase, uint256 totalDebtBase,,,,) = _getUserAccountData(address(this));
        if (_percent == 10000 && (totalCollateralBase > 0 || totalDebtBase > 0)) {
            revert UnleverageNotComplete();
        }
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
         * if rebalance unleverage
         *      call unleverage function
         * if rebalance leverage
         *      call leverage
         */
        if (params.healthfactorIsOverMaximum) {
            _leverage(params.data);
        } else {
            _unleverageToMatchHealthfactor(params.data);
        }
    }

    function _unleverageToMatchHealthfactor(bytes memory _dynamicParams) internal {
        DataTypes.DynamicSwapData memory params = abi.decode(_dynamicParams, (DataTypes.DynamicSwapData));

        address[] memory pricedAssets = new address[](2);
        pricedAssets[0] = address(_position.collateral.token);
        pricedAssets[1] = address(_position.debt.token);
        uint256[] memory prices = oracle.getAssetsPrices(pricedAssets);

        uint256 collateralBorrowBaseWeiPrice = prices[0] * params.amount / 10 ** _position.collateral.decimals;
        uint256 debtSwapEstimation = collateralBorrowBaseWeiPrice * 10 ** _position.debt.decimals / prices[1];
        uint256 percent = debtSwapEstimation * 10000 / _position.debt.debtToken.balanceOf(address(this));

        /**
         * Execute the Flashloan
         */
        (
            address[] memory assets,
            uint256[] memory amounts,
            uint256[] memory interestRateModes,
            FlashloanData memory unleverageParams
        ) = _getFlashloanData(percent, address(_position.collateral.token), 0, FlashloanCallbackType.UNLEVERAGE, _dynamicParams);

        _flashloan(
            address(this), assets, amounts, interestRateModes, address(this), abi.encode(unleverageParams), REFERAL
        );

        IERC20 collateral = _position.collateral.token;
        uint256 collateralBalance = _position.collateral.token.balanceOf(address(this));
        if(collateralBalance > 0) {
            _supply(address(collateral), collateralBalance, address(this), REFERAL);
        }

        (,,,,, uint256 healthfactor) = _getUserAccountData(address(this));
        if (healthfactor > _position.healthfactor.max || healthfactor < _position.healthfactor.min) {
            revert LeverageHealthfactorNotMatch();
        }
    }

    /**
     * @notice Handles the callback from Aave's flashloan operation.
     * @dev This function is called by Aave's lending pool contract after a flashloan is executed. It processes the flashloan based on the callback type specified in the flashloan parameters.
     * @param _amounts The amounts of the assets borrowed in the flashloan.
     * @param _premiums The fees associated with the flashloan.
     * @param _initiator The initiator of the flashloan.
     * @param _params Encoded flashloan parameters including the callback type and any additional data required for processing the flashloan.
     * @return Returns true if the flashloan callback was executed successfully.
     */
    function executeOperation(
        address[] calldata,
        uint256[] calldata _amounts,
        uint256[] calldata _premiums,
        address _initiator,
        bytes calldata _params
    ) external returns (bool) {
        if (msg.sender != address(pool)) revert NotAavePool();
        if (_initiator != address(this)) revert WrongInitiator();

        FlashloanData memory params = abi.decode(_params, (FlashloanData));

        if (params.callback == FlashloanCallbackType.LEVERAGE) {
            _executeFlashloanLeverage(params.data);
        }

        if (params.callback == FlashloanCallbackType.UNLEVERAGE) {
            uint256 totalToRepay = _amounts[0] + _premiums[0];
            _executeFlashloanUnleverage(params.data, params.percent);

            //Increase allowance for flashloan repay
            _position.collateral.token.safeIncreaseAllowance(address(pool), totalToRepay);
        }

        return true;
    }

    function _executeFlashloanLeverage(bytes memory _data) internal {
        /**
         * Steps resume
         *      - Swap borrowed assets to the collateral
         *      - Deposit collateral on pool
         *      - Validate HealthFactor
         */
        DataTypes.DynamicSwapData memory params = abi.decode(_data, (DataTypes.DynamicSwapData));
        _swap(params);

        uint256 collateralBal = _position.collateral.token.balanceOf(address(this));
        _supply(address(_position.collateral.token), collateralBal, address(this), REFERAL);
    }

    function _executeFlashloanUnleverage(bytes memory _data, uint256 _percent) internal {
        /**
         * Steps resume
         * - Calculate the amount to borrow to unleverage
         * - Execute the flashloan
         *      - Swap collateral flashloaned to repay the debt
         *      - Call repay with repayWithATokens(address asset,uint256 amount,uint256 interestRateMode) function
         *      - withdraw remining collateral
         *      - send collateral to the vault
         */

        DataTypes.DynamicSwapData memory params = abi.decode(_data, (DataTypes.DynamicSwapData));
        _swap(params);

        uint256 debtTokenBalance = _position.debt.token.balanceOf(address(this));
        uint256 initalCollateralAmount = _position.collateral.aToken.balanceOf(address(this));
        uint256 initalDebtAmount = _position.debt.debtToken.balanceOf(address(this));
        uint256 initalCollatDebtRatio = initalCollateralAmount * 1 ether / initalDebtAmount;
        uint256 amountToRepay = initalDebtAmount * _percent / 10000;
        uint256 remainingDebt = initalDebtAmount - amountToRepay;
        uint256 amountToWithdraw = initalCollateralAmount - (initalCollatDebtRatio * remainingDebt / 1 ether);

        //tolerate 2% deviation 
        uint256 minAmoutToRepay = amountToRepay * 98 / 100;
        if(minAmoutToRepay > debtTokenBalance) revert InsufficientTokenToRepay(amountToRepay, debtTokenBalance);
        
        if(amountToRepay > debtTokenBalance) 
            amountToRepay = debtTokenBalance;

        _repay(
            address(_position.debt.token), 
            amountToRepay, 
            _position.debt.debtType, 
            address(this)
        );

        _withdraw(address(_position.collateral.token), amountToWithdraw, address(this));
    }
}
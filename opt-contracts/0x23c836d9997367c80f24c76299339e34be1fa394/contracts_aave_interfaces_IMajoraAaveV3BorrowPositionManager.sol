// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import {IERC20} from "./openzeppelin_contracts_token_ERC20_IERC20.sol";

import {IAaveOracle} from "./aave_core-v3_contracts_interfaces_IAaveOracle.sol";
import {IMajoraPositionManager} from "./contracts_interfaces_IMajoraPositionManager.sol";
import {IMajoraAaveV3PositionManager} from "./contracts_aave_interfaces_IMajoraAaveV3PositionManager.sol";

interface IMajoraAaveV3BorrowPositionManager is IMajoraPositionManager, IMajoraAaveV3PositionManager {

    /// @notice Error thrown when a repay operation is not covered by a swap.
    error RepayNotCoveredWithSwap();
    error DynamicParametersNeeded();

    event RepayExecuted(uint256 percent);
    event BorrowExecuted(uint256 borrowed);

    /**
     * @dev Represents the status of a borrow position, including flags for rebalancing, the available amount for repayment, and health factors.
     * @param emptyBorrow Indicates if the borrow position is empty.
     * @param toRebalance Indicates if the position needs rebalancing.
     * @param positionDeltaIsPositive Indicates if the position delta is positive.
     * @param availableTokenForRepay The amount of token available for repayment.
     * @param deltaAmount The amount of delta in the position.
     * @param healthFactor The current health factor of the position.
     * @param healthFactorDesired The desired health factor.
     * @param rebalanceAmountToRepay The amount to repay during rebalance.
     * @param collateralAmount The amount of collateral.
     * @param debtAmount The amount of debt.
     */
    struct BorrowStatus {
        bool empty;
        bool toRebalance;
        bool hasDust;
        bool positionDeltaIsPositive;
        uint256 availableTokenForRepay;
        uint256 deltaAmount;
        uint256 healthFactor;
        uint256 healthFactorDesired;
        uint256 rebalanceAmountToRepay;
        uint256 collateralAmount;
        uint256 debtAmount;
    }

    function status(bool _withSpecificAvailableTokenForRepay, uint256 _availableTokenForRepay, uint256 _percent) external view returns (BorrowStatus memory state);
    function borrow(uint256 _addCollateralAmount) external;
    function repay(bytes memory _dynamicParams, uint256 _percent) external;
    function borrowAmountFor(uint256 _collateral) external view returns (uint256);
    function returnedAmountAfterRepay(uint256 _repay, uint256 _percent) external view returns (uint256);
}
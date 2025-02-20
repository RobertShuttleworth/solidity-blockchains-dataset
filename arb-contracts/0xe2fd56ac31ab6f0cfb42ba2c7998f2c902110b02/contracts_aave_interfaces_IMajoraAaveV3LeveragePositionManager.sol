// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import {IERC20} from "./openzeppelin_contracts_token_ERC20_IERC20.sol";

import {IAaveOracle} from "./aave_core-v3_contracts_interfaces_IAaveOracle.sol";
import {IMajoraPositionManager} from "./contracts_interfaces_IMajoraPositionManager.sol";
import {IMajoraAaveV3PositionManager} from "./contracts_aave_interfaces_IMajoraAaveV3PositionManager.sol";

interface IMajoraAaveV3LeveragePositionManager is IMajoraPositionManager, IMajoraAaveV3PositionManager {

    /// @notice Error thrown when the leverage operation does not match the desired health factor.
    error LeverageHealthfactorNotMatch();

    /// @notice Error thrown when the unleverage operation is not complete.
    error UnleverageNotComplete();

    /// @notice Error thrown when the unleverage operation is not complete.
    error InsufficientTokenToRepay(uint256 amountToRepay, uint256 availableAmount);

    /**
     * @dev Represents the status of a leverage position, including flags for rebalancing and health factors.
     * @param emptyLeverage Indicates if the leverage position is empty.
     * @param toRebalance Indicates if the position needs rebalancing.
     * @param collateralAmount The amount of collateral.
     * @param debtAmount The amount of debt.
     * @param healthFactor The current health factor of the position.
     * @param healthFactorDesired The desired health factor.
     */
    struct LeverageStatus {
        bool empty;
        bool toRebalance;
        bool hasDust;
        uint256 collateralAmount;
        uint256 debtAmount;
        uint256 healthFactor;
        uint256 healthFactorDesired;
    }


    function leverage(uint256 _addCollateralAmount, bytes memory _dynamicParams) external;
    function unleverage(bytes memory _dynamicParams, uint256 _percent) external;
    function returnedAmountAfterUnleverage(uint256 _percent) external view returns (uint256);
    function status() external view returns (LeverageStatus memory status);
}
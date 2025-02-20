// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import {IERC20} from "./openzeppelin_contracts_token_ERC20_IERC20.sol";

import {IMajoraPortal} from "./majora-finance_portal_contracts_interfaces_IMajoraPortal.sol";
import {DataTypes} from "./majora-finance_libraries_contracts_DataTypes.sol";
import {IMajoraDataAggregator} from "./majora-finance_core_contracts_interfaces_IMajoraDataAggregator.sol";
import {LibOracleState} from "./majora-finance_libraries_contracts_LibOracleState.sol";

import {IPool} from "./aave_core-v3_contracts_interfaces_IPool.sol";
import {IAaveOracle} from "./aave_core-v3_contracts_interfaces_IAaveOracle.sol";
import {DataTypes as AaveDataType} from "./aave_core-v3_contracts_protocol_libraries_types_DataTypes.sol";
import {PercentageMath} from "./aave_core-v3_contracts_protocol_libraries_math_PercentageMath.sol";
import {WadRayMath} from "./aave_core-v3_contracts_protocol_libraries_math_WadRayMath.sol";

import {IMajoraPositionManagerDataAggregator} from "./contracts_interfaces_IMajoraPositionManagerDataAggregator.sol";
import {IMajoraAaveV3PositionManager} from "./contracts_aave_interfaces_IMajoraAaveV3PositionManager.sol";
import {IMajoraAaveV3LeveragePositionManager} from "./contracts_aave_interfaces_IMajoraAaveV3LeveragePositionManager.sol";
import {IMajoraAddressesProvider} from "./majora-finance_access-manager_contracts_interfaces_IMajoraAddressesProvider.sol";

/**
 * @title Majora Aave V3 Borrow Position Manager Info
 * @author Majora Development Association
 * @notice This contract provides detailed information and utilities for managing positions within the Aave V3 protocol through the Majora Finance ecosystem. It facilitates the retrieval of critical data necessary for the strategic management of assets, including rebalancing and health factor maintenance.
 * @dev The contract integrates with Aave V3's lending pool and oracle to fetch real-time data and compute key metrics for position management. It also interfaces with Majora's core contracts to execute operations like rebalancing. The contract is designed to be read-only, providing external view functions to access position data.
 */
contract MajoraAaveV3LeveragePositionManagerDataAggregator is IMajoraPositionManagerDataAggregator {
    using WadRayMath for uint256;
    using PercentageMath for uint256;
    using LibOracleState for DataTypes.OracleState;

    /// @notice The Aave protocol's lending pool contract instance.
    IPool public immutable pool;
    /// @notice The Aave protocol's oracle contract instance for fetching asset prices.
    IAaveOracle public immutable oracle;
    /// @notice The Majora address provider contract instance
    IMajoraAddressesProvider public immutable addressProvider;

    constructor(
        address _pool, 
        address _oracle, 
        address _addressProvider
    ) {
        pool = IPool(_pool);
        oracle = IAaveOracle(_oracle);
        addressProvider = IMajoraAddressesProvider(_addressProvider);
    }

    /**
     * @notice Provides information necessary for executing a rebalance on a position manager.
     * @dev This function returns the rebalance execution information for a given position manager, including the vault owner, block index, and dynamic parameters for rebalancing.
     *      It calculates the necessary parameters based on the current state of the position, such as the amount to leverage or deleverage to reach the desired health factor.
     * @param _pm The address of the position manager contract.
     * @return info A struct containing the vault owner, block index, and dynamic parameters for rebalancing the position.
     */
    function positionManagerRebalanceExecutionInfo(address _pm, uint256[] memory, uint256[] memory)
        external
        view
        returns (DataTypes.PositionManagerRebalanceExecutionInfo memory info)
    {
        IMajoraAaveV3LeveragePositionManager pm = IMajoraAaveV3LeveragePositionManager(_pm);
        info.vault = pm.owner();
        info.blockIndex = pm.blockIndex();

        IMajoraAaveV3LeveragePositionManager.Position memory _position = pm.position();
        IMajoraAaveV3LeveragePositionManager.LeverageStatus memory status = pm.status();

        info.dynParamsType = DataTypes.DynamicParamsType.PORTAL_SWAP;

        uint256 collateralBasePrice = oracle.getAssetPrice(address(_position.collateral.token));
        uint256 debtBasePrice = oracle.getAssetPrice(address(_position.debt.token));
        uint256 collateralUSD = collateralBasePrice * status.collateralAmount / 10 ** _position.collateral.decimals;
        uint256 debtUSD = debtBasePrice * status.debtAmount / 10 ** _position.debt.decimals;
        uint256 netUSDPosition = collateralUSD - debtUSD;

        uint256 debtDesiredForHf = _computeFlashloanUSDAmountToMatchHealthfactor(
            _position.collateral.lts,
            netUSDPosition,
            _position.healthfactor.desired
        );

        if (status.healthFactor > status.healthFactorDesired) {
            //leverage
            uint256 flashloanAmount =
                (debtDesiredForHf * 10 ** _position.debt.decimals / debtBasePrice) - status.debtAmount;

            info.dynParamsInfo = abi.encode(
                DataTypes.DynamicSwapParams({
                    fromToken: address(_position.debt.token),
                    toToken: address(_position.collateral.token),
                    value: flashloanAmount,
                    valueType: DataTypes.SwapValueType.INPUT_STRICT_VALUE
                })
            );
        } else {
            //unleverage

            //simulate repay to get collateral remaining
            //simulate the amount of borrow to match HF
            //toSell = currentBorrow - amount of borrow to matched HF

            uint256 debtAmountUSD = debtBasePrice * status.debtAmount / 10 ** _position.debt.decimals;
            uint256 toSellUSD = debtAmountUSD - debtDesiredForHf;

            uint256 toSell = toSellUSD * 10 ** _position.collateral.decimals / collateralBasePrice;

            info.dynParamsInfo = abi.encode(
                DataTypes.DynamicSwapParams({
                    fromToken: address(_position.collateral.token),
                    toToken: address(_position.debt.token),
                    value: toSell,
                    valueType: DataTypes.SwapValueType.INPUT_STRICT_VALUE
                })
            );
        }
    }

    function _computeFlashloanUSDAmountToMatchHealthfactor(
        uint256 lts,
        uint256 initialCollateralAmount,
        uint256 hfDesired
    ) internal pure returns (uint256) {

        bool ended;
        uint256 usdValueBorrowable = (initialCollateralAmount * lts / 10000);
        uint256 initialBorrowAmount = usdValueBorrowable * 1e18 / hfDesired;

        uint256 totalCollateral = initialCollateralAmount;
        uint256 totalBorrow = initialBorrowAmount;
        uint256 previousBorrow = initialBorrowAmount;
        uint256 previousCumulated = initialBorrowAmount;

        while (!ended) {
            totalCollateral = totalCollateral + previousBorrow;
            totalBorrow = (totalCollateral * lts * 1e18 / 10000) / hfDesired;
            previousBorrow = totalBorrow - previousCumulated;
            previousCumulated = previousCumulated + previousBorrow;

            if (previousBorrow <= initialCollateralAmount / 500) {
                ended = true;
            }
        }

        return totalBorrow;
    }
}
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
import {IMajoraAaveV3BorrowPositionManager} from "./contracts_aave_interfaces_IMajoraAaveV3BorrowPositionManager.sol";
import {IMajoraAddressesProvider} from "./majora-finance_access-manager_contracts_interfaces_IMajoraAddressesProvider.sol";

/**
 * @title Majora Aave V3 Position Manager Info
 * @author Majora Development Association
 * @notice This contract provides detailed information and utilities for managing positions within the Aave V3 protocol through the Majora Finance ecosystem. It facilitates the retrieval of critical data necessary for the strategic management of assets, including rebalancing and health factor maintenance.
 * @dev The contract integrates with Aave V3's lending pool and oracle to fetch real-time data and compute key metrics for position management. It also interfaces with Majora's core contracts to execute operations like rebalancing. The contract is designed to be read-only, providing external view functions to access position data.
 */
contract MajoraAaveV3BorrowPositionManagerDataAggregator is IMajoraPositionManagerDataAggregator {
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
     * @param _from Array of token addresses to swap from (not used in current implementation).
     * @param _to Array of token addresses to swap to (not used in current implementation).
     * @return info A struct containing the vault owner, block index, and dynamic parameters for rebalancing the position.
     */
    function positionManagerRebalanceExecutionInfo(address _pm, uint256[] memory _from, uint256[] memory _to)
        external
        view
        returns (DataTypes.PositionManagerRebalanceExecutionInfo memory info)
    {
        IMajoraDataAggregator dataAggregator = IMajoraDataAggregator(addressProvider.dataAggregator());
        IMajoraAaveV3BorrowPositionManager pm = IMajoraAaveV3BorrowPositionManager(_pm);
        info.vault = pm.owner();
        info.blockIndex = pm.blockIndex();

        IMajoraAaveV3BorrowPositionManager.Position memory _position = pm.position();
        IMajoraAaveV3BorrowPositionManager.BorrowStatus memory status = pm.status(false, 0, 10000);

        if(pm.ownerIsMajoraVault()) {
            if (status.healthFactor > status.healthFactorDesired) {
                //estimate additional borrow
                DataTypes.OracleState memory _oracle;
                _oracle.vault = info.vault;
                _oracle.addTokenAmount(address(_position.debt.token), _getBorrowAmountToMatchHealthfactor(address(pm), _position));

                //pass estimated additional borrow to partial vault strategy execution
                info.partialEnter = dataAggregator.getPartialVaultStrategyEnterExecutionInfo(
                    info.vault, _from, _to, _oracle
                );
            } else {
                info.partialExit = dataAggregator.getPartialVaultStrategyExitExecutionInfo(
                    info.vault, _from, _to
                );
                                
                uint256 toRepayAmount = _getRepayAmountToMatchHealthfactor(_pm, _position);

                DataTypes.OracleState memory oracleState;
                if(info.partialExit.blocksInfo.length > 0) {
                    oracleState = info.partialExit.blocksInfo[
                        _from[_from.length - 1]
                    ].oracleStatus.clone();
                } else {
                    oracleState = info.partialExit.startOracleStatus.clone();
                }

                uint256 availableAmount = oracleState.findTokenAmount(address(_position.debt.token)) + _position.debt.token.balanceOf(_pm);

                if (availableAmount < toRepayAmount) {
                    uint256 missingAmount = toRepayAmount - availableAmount;
                    info.dynParamsType = DataTypes.DynamicParamsType.PORTAL_SWAP;
                    info.dynParamsInfo = abi.encode(
                        DataTypes.DynamicSwapParams({
                            fromToken: address(_position.collateral.token),
                            toToken: address(_position.debt.token),
                            value: missingAmount * 1000001 / 1000000,
                            valueType: DataTypes.SwapValueType.OUTPUT_STRICT_VALUE
                        })
                    );

                    oracleState.setTokenAmount(address(_position.debt.token), 0);
                } else {
                    oracleState.removeTokenAmount(address(_position.debt.token), toRepayAmount);
                    info.partialEnter = dataAggregator.getPartialVaultStrategyEnterExecutionInfo(
                        info.vault, _from, _to, oracleState
                    );
                }
            }
        } else {
            if (status.healthFactor < status.healthFactorDesired) {
                uint256 toRepayAmount = _getRepayAmountToMatchHealthfactor(_pm, _position);
                uint256 availableAmount = _position.debt.token.balanceOf(address(pm));
                if (availableAmount < toRepayAmount) {
                    uint256 missingAmount = toRepayAmount - availableAmount;
                    info.dynParamsType = DataTypes.DynamicParamsType.PORTAL_SWAP;
                    info.dynParamsInfo = abi.encode(
                        DataTypes.DynamicSwapParams({
                            fromToken: address(_position.collateral.token),
                            toToken: address(_position.debt.token),
                            value: missingAmount * 1000001 / 1000000,
                            valueType: DataTypes.SwapValueType.OUTPUT_STRICT_VALUE
                        })
                    );
                }
            }
        }
    }

    function _getBorrowAmountToMatchHealthfactor(address _pm, IMajoraAaveV3BorrowPositionManager.Position memory _position)
        internal
        view
        returns (uint256)
    {
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
        ) = pool.getUserAccountData(_pm);

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
        uint256 assetBaseWeiPrice = oracle.getAssetPrice(address(_position.debt.token));
        uint256 toBorrowBase = (
            totalCollateralBase.percentMul(currentLiquidationThreshold) * 1e18 / _position.healthfactor.desired
        ) - totalDebtBase;
        uint256 borrowAmount = toBorrowBase * 10 ** _position.debt.decimals / assetBaseWeiPrice;

        return borrowAmount;
    }

    function _getRepayAmountToMatchHealthfactor(address _pm, IMajoraAaveV3BorrowPositionManager.Position memory _position)
        internal
        view
        returns (uint256)
    {
        /**
         * Fetch Aave user account data
         */
        (uint256 totalCollateralBase, uint256 totalDebtBase,, uint256 currentLiquidationThreshold,,) =
            pool.getUserAccountData(_pm);

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
        uint256 totalBorrowBase =
            totalCollateralBase.percentMul(currentLiquidationThreshold) * 1e18 / _position.healthfactor.desired;
        uint256 amountToRepayBase = totalDebtBase - totalBorrowBase;
        uint256 amountToRepay = amountToRepayBase * 10 ** _position.debt.decimals / assetBaseWeiPrice;

        return amountToRepay;
    }
}
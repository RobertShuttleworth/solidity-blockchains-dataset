// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import {IERC20} from "./openzeppelin_contracts_token_ERC20_IERC20.sol";

import {IAaveOracle} from "./aave_core-v3_contracts_interfaces_IAaveOracle.sol";
import {IMajoraPositionManager} from "./contracts_interfaces_IMajoraPositionManager.sol";

interface IMajoraAaveV3PositionManager is IMajoraPositionManager {

    /// @notice Error thrown when the contract has already been initialized.
    error AlreadyInitialized();

    /// @notice Error thrown when the caller is not the owner.
    error NotOwner();

    /// @notice Error thrown when the caller is not an operator.
    error NotOperator();

    /// @notice Error thrown when the caller is not the Aave pool.
    error NotAavePool();

    /// @notice Error thrown when the initiator of the operation is wrong.
    error WrongInitiator();

    /// @notice Error thrown when the initiator of the operation is wrong.
    error BadHealthfactorConfiguration();

    /// @notice Error thrown when the initiator of the operation is wrong.
    error PositionIsNotClosed();

    enum FlashloanCallbackType {
        LEVERAGE,
        UNLEVERAGE
    }

    /**
     * @dev Represents the parameters required for initializing a position manager.
     * @param leverageMode Indicates if the position is in leverage mode.
     * @param collateral The address of the collateral ERC20 token.
     * @param collateralDecimals The number of decimals of the collateral token.
     * @param borrowed The address of the borrowed ERC20 token.
     * @param borrowedDecimals The number of decimals of the borrowed token.
     * @param eModeCategoryId The category ID for Aave's eMode, enhancing certain aspects of the position.
     * @param debtType The type of debt (stable or variable).
     * @param hfMin The minimum health factor to maintain, below which the position is considered at risk.
     * @param hfMax The maximum health factor, above which the position may be adjusted to optimize performance.
     * @param hfDesired The desired health factor to aim for during position adjustments.
     */
    struct InitializationParams {
        IERC20 collateral;
        uint256 collateralDecimals;
        IERC20 borrowed;
        uint256 borrowedDecimals;
        uint8 eModeCategoryId;
        uint256 debtType;
        uint256 hfMin;
        uint256 hfMax;
        uint256 hfDesired;
    }

    /**
     * @dev Represents the state of a position, including whether it's in leverage mode, its eMode category, the oracle used for price feeds, and detailed information about its collateral, debt, and health factor.
     * @param leverageMode Indicates if the position is in leverage mode.
     * @param eModeCategoryId The category ID for Aave's eMode, enhancing certain aspects of the position.
     * @param oracle The Aave oracle used for fetching current asset prices.
     * @param collateral Detailed information about the collateral of the position.
     * @param debt Detailed information about the debt of the position.
     * @param healthfactor Detailed information about the health factor of the position.
     */
    struct Position {
        uint8 eModeCategoryId;
        IAaveOracle oracle;
        Collateral collateral;
        Debt debt;
        Healthfactor healthfactor;
    }

    /**
     * @dev Represents the collateral used in a position, including the token, its corresponding aToken, decimals, loan-to-value (LTV) ratio, and liquidation threshold (LTS).
     * @param token The address of the underlying collateral token.
     * @param aToken The address of the corresponding aToken for the collateral.
     * @param decimals The number of decimals of the collateral token.
     * @param ltv The maximum loan-to-value ratio allowed for borrowing against the collateral.
     * @param lts The liquidation threshold, specifying the point at which the position is considered undercollateralized and subject to liquidation.
     */
    struct Collateral {
        IERC20 token;
        IERC20 aToken;
        uint256 decimals;
        uint256 ltv;
        uint256 lts;
    }
    
    /**
     * @dev Represents the debt of a user, including the token borrowed, the type of debt, and its decimals.
     * @param token The address of the underlying token.
     * @param debtToken The address of the debt token.
     * @param debtType The type of debt (stable or variable).
     * @param decimals The number of decimals of the debt token.
     */
    struct Debt {
        IERC20 token;
        IERC20 debtToken;
        uint256 debtType;
        uint256 decimals;
    }
    
    /**
     * @dev Represents the health factor ranges for maintaining a safe position.
     * @param min The minimum health factor to avoid liquidation.
     * @param max The maximum health factor, indicating an overly safe position.
     * @param desired The desired health factor to aim for during rebalances.
     */
    struct Healthfactor {
        uint256 min;
        uint256 max;
        uint256 desired;
    }

    /**
     * @dev Represents the data required for executing a flashloan, including the callback type, additional data, and the percentage of the position to use.
     * @param callback The type of callback to execute after the flashloan.
     * @param data Additional data to pass to the callback.
     * @param percent The percentage of the position to use for the flashloan.
     */
    struct FlashloanData {
        FlashloanCallbackType callback;
        bytes data;
        uint256 percent;
    }

    event RebalanceExecuted();
    event HealthfactorConfigChanged(uint256 _minHf, uint256 _desiredHf, uint256 _maxHf);

    function position() external view returns (Position memory);
    function refreshAaveData() external;
    function changeHealthfactorConfig(
        uint256 _minHf,
        uint256 _desiredHf,
        uint256 _maxHf
    ) external;
}
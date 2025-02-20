// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

/// @title IPearBase Interface
/// @notice Basic interface for common functions across Pear-related contracts.
interface IPearBase {
    /// @notice Marks the different execution state of a position
    enum ExecutionState {
        Idle,
        Pending,
        Success,
        Failed
    }

    /// @notice Marks the status of a position
    enum PositionStatus {
        NotExecuted,
        Opened,
        Closed,
        Transferred,
        Liquidated
    }

    struct PositionData {
        bool isLong;
        address collateralToken;
        address marketAddress;
        bytes32 orderKey;
        ExecutionState orderExecutionState;
        bool isOrderMarketIncrease;
        PositionStatus positionStatus;
    }

    struct PairPositionData {
        PositionData long;
        PositionData short;
        uint256 timestamp;
    }

    struct CreateOrderArgs {
        address initialCollateralToken;
        address[] swapPath;
        address marketAddress;
        uint256 sizeDelta;
        uint256 initialCollateralDeltaAmount;
        uint256 minOut;
        uint256 executionFee;
        uint256 acceptablePrice;
        uint256 triggerPrice;
    }

    struct OpenPositionsArgs {
        CreateOrderArgs long;
        CreateOrderArgs short;
        uint256 totalAmountIn;
    }
}
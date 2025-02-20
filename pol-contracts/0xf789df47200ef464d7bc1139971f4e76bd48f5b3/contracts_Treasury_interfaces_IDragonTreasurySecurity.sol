// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

interface IDragonTreasurySecurity {
    // Admin management
    function isEmergencyAdmin(address account) external view returns (bool);
    function addEmergencyAdmin(address admin) external;
    function removeEmergencyAdmin(address admin) external;

    // Emergency operations
    function emergencyWithdraw(
        address token,
        address to,
        uint256 amount
    ) external;
    function pause() external;
    function unpause() external;
    function resetSpendingLimits() external;

    // Security checks
    function checkSpendingLimit(
        address token,
        uint256 amount
    ) external view returns (bool);

    // Recovery functions
    function recoverStrayTokens(
        address token,
        address to
    ) external;

    // View functions
    function lastEmergencyAction() external view returns (uint256);
    function emergencyActionsInPeriod() external view returns (uint256);
    function lastPeriodReset() external view returns (uint256);
    function paused() external view returns (bool);

    // Constants
    function EMERGENCY_TIMELOCK() external view returns (uint256);
    function MAX_EMERGENCY_ACTIONS_PER_PERIOD() external view returns (uint256);
    function PERIOD_LENGTH() external view returns (uint256);

    // Events
    event EmergencyActionTriggered(
        address indexed triggeredBy,
        uint256 indexed proposalId,
        string actionType
    );
    event EmergencyWithdrawal(
        address indexed token,
        address indexed to,
        uint256 amount,
        uint256 timestamp
    );
    event SpendingLimitUpdated(
        address indexed token,
        uint256 oldLimit,
        uint256 newLimit
    );
    event EmergencyAdminAdded(address indexed admin);
    event EmergencyAdminRemoved(address indexed admin);
    event SecurityParametersUpdated(
        uint256 newEmergencyTimelock,
        uint256 newMaxEmergencyActions,
        uint256 newPeriodLength
    );
    event StrayTokensRecovered(
        address indexed token,
        address indexed to,
        uint256 amount
    );
    event SpendingLimitsReset(uint256 timestamp);
}
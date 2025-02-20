// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "./openzeppelin_contracts_access_AccessControl.sol";
import "./openzeppelin_contracts_utils_Pausable.sol";
import "./openzeppelin_contracts_token_ERC20_IERC20.sol";
import "./openzeppelin_contracts_utils_ReentrancyGuard.sol";
import "./contracts_Treasury_interfaces_IDragonTreasurySecurity.sol";
import "./contracts_Treasury_interfaces_IDragonTreasuryCore.sol";

contract DragonTreasurySecurity is IDragonTreasurySecurity, AccessControl, Pausable, ReentrancyGuard {
    bytes32 public constant CORE_ROLE = keccak256("CORE_ROLE");
    bytes32 public constant EMERGENCY_ADMIN_ROLE = keccak256("EMERGENCY_ADMIN_ROLE");

    // Constants
    uint256 public constant override EMERGENCY_TIMELOCK = 3 days;
    uint256 public constant override MAX_EMERGENCY_ACTIONS_PER_PERIOD = 3;
    uint256 public constant override PERIOD_LENGTH = 7 days;

    // State variables
    IDragonTreasuryCore public immutable treasuryCore;
    uint256 private _lastEmergencyAction;
    uint256 private _emergencyActionsInPeriod;
    uint256 private _lastPeriodReset;

    constructor(address _treasuryCore) {
        require(_treasuryCore != address(0), "DragonTreasurySecurity: invalid treasury core");
        
        treasuryCore = IDragonTreasuryCore(_treasuryCore);
        
        // Grant roles
        _grantRole(DEFAULT_ADMIN_ROLE, _treasuryCore);
        _grantRole(CORE_ROLE, _treasuryCore);

        // Initialize owners from MultiSig as emergency admins
        address[] memory owners = treasuryCore.multiSig().getOwners();
        for (uint i = 0; i < owners.length; i++) {
            _grantRole(EMERGENCY_ADMIN_ROLE, owners[i]);
            emit EmergencyAdminAdded(owners[i]);
        }

        _lastPeriodReset = block.timestamp;
    }

    // Override paused() from both Pausable and IDragonTreasurySecurity
    function paused() public view override(Pausable, IDragonTreasurySecurity) returns (bool) {
        return super.paused();
    }

    // Admin management
    function isEmergencyAdmin(address account) external view override returns (bool) {
        return hasRole(EMERGENCY_ADMIN_ROLE, account);
    }

    function addEmergencyAdmin(address admin) external override onlyRole(DEFAULT_ADMIN_ROLE) {
        require(admin != address(0), "DragonTreasurySecurity: invalid address");
        require(!hasRole(EMERGENCY_ADMIN_ROLE, admin), "DragonTreasurySecurity: already admin");
        _grantRole(EMERGENCY_ADMIN_ROLE, admin);
        emit EmergencyAdminAdded(admin);
    }

    function removeEmergencyAdmin(address admin) external override onlyRole(DEFAULT_ADMIN_ROLE) {
        require(hasRole(EMERGENCY_ADMIN_ROLE, admin), "DragonTreasurySecurity: not admin");
        _revokeRole(EMERGENCY_ADMIN_ROLE, admin);
        emit EmergencyAdminRemoved(admin);
    }

    // Emergency operations
    function emergencyWithdraw(
        address token,
        address to,
        uint256 amount
    ) external override onlyRole(EMERGENCY_ADMIN_ROLE) whenPaused nonReentrant {
        require(to != address(0), "DragonTreasurySecurity: invalid recipient");
        require(
            block.timestamp >= _lastEmergencyAction + EMERGENCY_TIMELOCK,
            "DragonTreasurySecurity: emergency timelock active"
        );

        if (token == address(0)) {
            require(amount <= address(treasuryCore).balance, "DragonTreasurySecurity: insufficient MATIC");
            (bool success, ) = to.call{value: amount}("");
            require(success, "DragonTreasurySecurity: MATIC transfer failed");
        } else {
            IDragonTreasuryCore.TokenInfo memory info = treasuryCore.getToken(token);
            require(info.isTracked, "DragonTreasurySecurity: token not tracked");
            
            require(
                amount <= IERC20(token).balanceOf(address(treasuryCore)),
                "DragonTreasurySecurity: insufficient balance"
            );
            require(IERC20(token).transfer(to, amount), "DragonTreasurySecurity: transfer failed");
        }

        _lastEmergencyAction = block.timestamp;
        _emergencyActionsInPeriod++;

        require(
            _emergencyActionsInPeriod <= MAX_EMERGENCY_ACTIONS_PER_PERIOD,
            "DragonTreasurySecurity: too many emergency actions"
        );

        emit EmergencyWithdrawal(token, to, amount, block.timestamp);
        emit EmergencyActionTriggered(msg.sender, 0, "emergency_withdraw");
    }

    function pause() external override onlyRole(EMERGENCY_ADMIN_ROLE) {
        _pause();
        emit EmergencyActionTriggered(msg.sender, 0, "pause");
    }

    function unpause() external override onlyRole(EMERGENCY_ADMIN_ROLE) {
        require(
            block.timestamp >= _lastEmergencyAction + EMERGENCY_TIMELOCK,
            "DragonTreasurySecurity: emergency timelock active"
        );
        _unpause();
        emit EmergencyActionTriggered(msg.sender, 0, "unpause");
    }

    function resetSpendingLimits() external override onlyRole(EMERGENCY_ADMIN_ROLE) whenPaused {
        require(
            block.timestamp >= _lastEmergencyAction + EMERGENCY_TIMELOCK,
            "DragonTreasurySecurity: emergency timelock active"
        );
        _emergencyActionsInPeriod = 0;
        _lastPeriodReset = block.timestamp;
        
        emit SpendingLimitsReset(block.timestamp);
        emit EmergencyActionTriggered(msg.sender, 0, "reset_limits");
    }

    // Security checks
    function checkSpendingLimit(
        address token,
        uint256 amount
    ) external view override returns (bool) {
        IDragonTreasuryCore.TokenInfo memory tokenInfo = treasuryCore.getToken(token);

        // Check daily limit
        uint256 spentToday = tokenInfo.spentToday;
        if (block.timestamp >= tokenInfo.lastSpendDay + 1 days) {
            spentToday = 0;
        }
        
        if (spentToday + amount > tokenInfo.dailyLimit) {
            return false;
        }

        // Check period limit
        uint256 currentPeriodSpending = 0;
        if (block.timestamp < _lastPeriodReset + PERIOD_LENGTH) {
            currentPeriodSpending = _emergencyActionsInPeriod;
        }

        return currentPeriodSpending < MAX_EMERGENCY_ACTIONS_PER_PERIOD;
    }

    // Recovery functions
    function recoverStrayTokens(
        address token,
        address to
    ) external override onlyRole(DEFAULT_ADMIN_ROLE) {
        require(to != address(0), "DragonTreasurySecurity: invalid recipient");
        require(token != address(0), "DragonTreasurySecurity: cannot recover MATIC");
        
        IDragonTreasuryCore.TokenInfo memory info = treasuryCore.getToken(token);
        require(!info.isTracked, "DragonTreasurySecurity: cannot recover tracked token");
        
        uint256 balance = IERC20(token).balanceOf(address(treasuryCore));
        require(balance > 0, "DragonTreasurySecurity: no balance to recover");
        
        require(IERC20(token).transfer(to, balance), "DragonTreasurySecurity: transfer failed");
        
        emit StrayTokensRecovered(token, to, balance);
    }

    // View functions
    function lastEmergencyAction() external view override returns (uint256) {
        return _lastEmergencyAction;
    }

    function emergencyActionsInPeriod() external view override returns (uint256) {
        return _emergencyActionsInPeriod;
    }

    function lastPeriodReset() external view override returns (uint256) {
        return _lastPeriodReset;
    }

    // Allow receiving MATIC
    receive() external payable {}
}
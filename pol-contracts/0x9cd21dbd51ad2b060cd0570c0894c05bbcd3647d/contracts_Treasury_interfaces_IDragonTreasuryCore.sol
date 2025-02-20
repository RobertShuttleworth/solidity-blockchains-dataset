// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "./contracts_Treasury_interfaces_IMultiSigWallet.sol";

interface IDragonTreasuryCore {
    struct TokenInfo {
        string name;
        string symbol;
        uint8 decimals;
        uint256 balance;
        bool isTracked;
        bool isCritical;
        uint256 dailyLimit;
        uint256 lastSpendDay;
        uint256 spentToday;
        address priceFeed;
    }

    // Module management functions
    function setFinanceModule(address module) external;
    function setGovernanceModule(address module) external;
    function setSecurityModule(address module) external;
    function setAnalyticsModule(address module) external;

    // Token management functions
    function addToken(address token, bool isCritical, uint256 dailyLimit, address priceFeed) external;
    function removeToken(address token) external;
    function handleTokenTransfer(address token, uint256 amount, bool isInflow) external;
    
    // View functions
    function getToken(address token) external view returns (TokenInfo memory);
    function getTrackedTokens() external view returns (address[] memory);
    function multiSig() external view returns (IMultiSigWallet);
    
    // Analytics functions
    function updateAnalytics() external;

    // System control functions
    function pause() external;
    function unpause() external;
    function version() external pure returns (string memory);

    // Events
    event TokenAdded(address indexed token, string name, string symbol, bool isCritical, address priceFeed);
    event TokenRemoved(address indexed token);
    event ModuleUpdated(string indexed moduleName, address indexed moduleAddress);
    event TokenTransferHandled(address indexed token, uint256 amount, bool isInflow, uint256 newBalance);
    event AnalyticsUpdated(uint256 timestamp);
}
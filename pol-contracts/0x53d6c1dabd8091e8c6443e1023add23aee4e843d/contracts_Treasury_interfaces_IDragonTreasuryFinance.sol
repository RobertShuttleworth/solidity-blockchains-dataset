// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

interface IDragonTreasuryFinance {
    struct CashFlowData {
        uint256 inflow;
        uint256 outflow;
        uint256 timestamp;
        mapping(address => uint256) tokenInflows;
        mapping(address => uint256) tokenOutflows;
    }

    // Cash flow management
    function updateCashFlow(
        address token,
        uint256 amount,
        bool isInflow
    ) external;

    // Price and value calculations
    function getTokenPriceUSD(address token) external view returns (uint256);
    function getTokenValueUSD(address token, uint256 amount) external view returns (uint256);
    function getTotalTreasuryValueUSD() external view returns (uint256);

    // Treasury metrics
    function getMonthlyBurn() external view returns (uint256);
    function calculateRunway() external view returns (uint256);
    
    // Historical data
    function getCashFlowHistory(uint256 months) external view returns (
        uint256[] memory timestamps,
        uint256[] memory inflows,
        uint256[] memory outflows
    );

    // View functions for flow data
    function monthlyFlows(uint256 timestamp) external view returns (
        uint256 inflow,
        uint256 outflow,
        uint256 timestamp_
    );
    function flowTimestamps(uint256 index) external view returns (uint256);
    function getFlowTimestampsLength() external view returns (uint256);

    // Events
    event CashFlowUpdated(
        uint256 timestamp,
        uint256 inflow,
        uint256 outflow,
        address indexed token,
        bool isInflow
    );
    event PriceUpdated(address indexed token, uint256 newPrice);
    event RunwayCalculated(uint256 runway, uint256 totalValue, uint256 monthlyBurn);
}
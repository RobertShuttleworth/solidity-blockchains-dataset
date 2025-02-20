// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

interface IHedgeVault {
    function SAY_TRADER_ROLE() external view returns (bytes32);

    function maxTotalDeposit() external view returns (uint256);

    function depositsPaused() external view returns (bool);

    function withdrawalsPaused() external view returns (bool);

    function fundsInTrading() external view returns (uint256);

    function initialize(address _asset, uint256 _maxTotalDeposit, address _owner) external;

    function totalAssets() external view returns (uint256);

    function totalDeposits() external view returns (uint256);

    function currentPnL() external view returns (int256);

    function deposit(uint256 assets, address receiver) external returns (uint256);

    function mint(uint256 shares, address receiver) external returns (uint256);

    function withdraw(uint256 assets, address receiver, address owner) external returns (uint256);

    function redeem(uint256 shares, address receiver, address owner) external returns (uint256);

    function fundStrategy(address trader, uint256 amount) external;

    function returnStrategyFunds(address trader, uint256 amount, int256 pnl) external;

    function setMaxTotalDeposit(uint256 newMax) external;

    function setWithdrawalsPaused(bool paused) external;

    function setDepositsPaused(bool paused) external;

    function pauseAll() external;

    function unpauseAll() external;
}
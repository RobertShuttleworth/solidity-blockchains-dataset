// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.25;

interface IRedeemOperator {
    // Events for logging actions
    event RegisterWithdrawal(address indexed user, uint256 shares);
    event ConfirmWithdrawal(address[] users, uint256[] amounts);
    event UpdateOperator(address oldOperator, address newOperator);
    event UpdateFeeReceiver(address oldFeeReceiver, address newFeeReceiver);
    event Sweep(address token);

    function registerWithdrawal(address _user, uint256 _shares) external;

    function pendingWithdrawersCount() external view returns (uint256);

    function pendingWithdrawers(uint256 _limit, uint256 _offset) external view returns (address[] memory result_);

    function allPendingWithdrawers() external view returns (address[] memory);

    function confirmWithdrawal(address[] calldata _Users, uint256 _totalGasTokenAmount) external;
}
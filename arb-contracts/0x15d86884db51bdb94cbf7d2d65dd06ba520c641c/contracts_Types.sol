// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

enum TypeOfInvestment {
    DepositOnly,
    AutoBuy
}

enum PositionStatus {
    SUCCESS,
    PENDING,
    CLAIMED,
    CANCELLED
}

struct PoolAmount {
    uint256 positionId;
    uint256 amount;
}

struct WithdrawParams {
    address user;
    address spender;
    address targetContract;
    uint256 positionId;
    bytes data;
    uint256 interestRate;
    uint256 returnTokenValue;
}

struct PositionArgs {
    address fromToken;
    address toToken;
    uint256 amount;
    uint256 interval;
    uint256 frequency;
}

struct Investment {
    uint256 amount;
    uint256 interestRate;
    uint256 depositTime;
    uint256 interval;
    uint256 frequency;
    address fromToken;
    address toToken;
    uint256 processed;
    TypeOfInvestment depositType;
    PositionStatus status;
}

event DCACycleComplete(
    address indexed user,
    uint256 positionId,
    uint256 lastCompletedOrder
);

event PositionCreated(
    address indexed user,
    uint256 indexed positionId,
    uint256 amount,
    address fromToken,
    address toToken
);
event Withdrawal(
    address indexed user,
    address indexed token,
    uint256 amount,
    uint256 indexed positionId
);
event WithdrawTokens(
    address indexed owner,
    address indexed token,
    uint256 amount
);
event WithdrawEth(address indexed owner, uint256 amount);
event NewExecutor(address executor);
event MetaTransactionExecuted(
    address indexed user,
    address indexed targetContract,
    bytes data,
    uint256 amount
);
event UpdatedIntervals(uint256[] intervals, bool isTrue);
event FeeUpdated(uint256 feeAutoBuy, uint256 feeDepositOnly);
event LogStringError(string reason);
event LogBytesError(bytes reason);

error InvalidAmount(uint256 amount);
error InvalidTimeInterval(uint256 interval);
error LowValue(uint256 value);
error InvalidFromToken(address fromToken);
error LowAllowance(address fromToken, address user);
error PositionNotFound(uint256 positionId);
error InsufficientFundsWithdraw(uint256 availableFunds, uint256 amount);
error InsufficientValue(uint256 value, uint256 amount);
error AlreadyHandled(address user, uint256 positionId);
// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity 0.8.28;

interface IErrors {
    // config
    error EssentialConfigNotSet(string key);
    error CapacityExceeded(uint256 capacity, uint256 old, uint256 appending);
    error UnexpectedState(uint256 expected, uint256 actual);

    // params
    error InvalidId(string key);
    error InvalidAmount(string key);
    error InvalidAddress(address addr);
    error InvalidArrayLength(uint256 a, uint256 b);
    error InvalidLotSize(uint256 positionSize, uint256 lotSize);
    error InvalidDecimals(uint256 decimals);
    error UnmatchedDecimals(uint256 decimals, uint256 expectDecimals);
    error InvalidCloseSize(uint256 closingSize, uint256 positionSize);

    // price
    error InvalidPriceTimestamp(uint256 timestamp);
    error MissingPrice(bytes32 oracleId);
    error LimitPriceNotMet(uint256 expected, uint256 actual);

    // access control
    error NotOwner(bytes32 positionId, address caller, address owner);
    error UnauthorizedRole(bytes32 requiredRole, address caller);
    error UnauthorizedAgent(address account, bytes32 positionId);
    error UnauthorizedCaller(address caller);

    // collateral
    error CollateralAlreadyExist(address tokenAddress);
    error CollateralNotExist(address tokenAddress);

    // market
    error InvalidMarketId(bytes32 marketId);
    error MarketNotExists(bytes32 marketId);
    error MarketAlreadyExist(bytes32 marketId);
    error MarketTradeDisabled(bytes32 marketId);
    error MarketFull();

    // pool
    error InsufficientLiquidity(uint256 requiredLiquidity, uint256 liquidityBalance); // 1e18, 1e18
    error DuplicatedAddress(address pool);
    error PoolAlreadyExist(address pool);
    error PoolNotExists(address pool);
    error CreateProxyFailed();

    // account
    error PositionAccountAlreadyExist(bytes32 positionId);
    error PositionAccountNotExist(bytes32 positionId);
    error UnsafePositionAccount(bytes32 positionId, uint256 safeType);
    error SafePositionAccount(bytes32 positionId, uint256 safeType);
    error InsufficientCollateralBalance(address collateralToken, uint256 balance, uint256 requiredAmount);
    error InsufficientCollateralUsd(uint256 requiredUsd, uint256 remainUsd);
    error InsufficientCollateral(uint256 required, uint256 remain);
    error InitialLeverageOutOfRange(uint256 leverage, uint256 leverageLimit);
    error PositionNotClosed(bytes32 positionId);
    error OnlySingleMarketPositionAllowed(bytes32 positionId);

    // potential bugs
    error ArrayAppendFailed();
    error AllocationLengthMismatch(uint256 len1, uint256 len2);
    error AllocationPositionMismatch(uint256 positionSize1, uint256 positionSize2);
    error OutOfBound(uint256 index, uint256 length);
    error BadAllocation(int256 maxX, int256 xi);

    // oracle
    error InvalidPrice(uint256 price);
    error InvalidPriceExpiration(uint256 expiration);
    error PriceExpired(uint256 timestamp, uint256 blockTimestamp);
    error IdMismatch(bytes32 id, bytes32 expectedId);
    error MissingSignature();
    error InvalidSequence(uint256 sequence, uint256 expectedSequence);
    error InvalidSignature(address signer, address expectSigner);
}
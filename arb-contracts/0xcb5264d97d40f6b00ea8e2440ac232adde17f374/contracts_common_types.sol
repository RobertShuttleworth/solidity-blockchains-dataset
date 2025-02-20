// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import './fhevm_lib_TFHE.sol';

enum SupportedOpertaions {
  SWAP,
  LENDING,
  BORROWING
}

enum SupportedPairs {
  eUSDC_eUSDT,
  eUSDC_eETH,
  eUSDC_eWBTC
}

enum SupportedPlainPairs {
  USDC_USDT,
  USDC_ETH,
  USDC_WBTC
}

enum SupportedEncryptedTokens {
  eUSDC,
  eUSDT,
  eETH,
  eWBTC
}

enum SupportedPlainTokens {
  USDC,
  USDT,
  ETH,
  WBTC
}

struct Order {
  euint32 amountIn;
  uint256 deadline; // order expiry time (should be pretty large compare to normal orders)
  address sender; // New field for the order sender
}

struct borrowOrder {
  eaddress asset;
  euint32 amount;
  euint32 interestRateMode;
  euint16 referralCode;
  eaddress onBehalfOf;
}

//Aggregated Order
struct AggregatedBorrowOrder {
  eaddress asset;
  euint32 amount;
  euint32 interestRateMode;
  euint16 referralCode;
  eaddress onBehalfOf;
}

struct AggregatedOrder {
  euint32 amountIn;
  uint256 deadline; // order expiry time (should be pretty large compare to normal orders)
}

struct SolvedAggregatedOrder {
  SupportedPairs orderType;
  SupportedEncryptedTokens assetIn;
  SupportedEncryptedTokens assetOut;
  uint32 orderRatio; // how much amountOut is received on swapping amountIn of assetIn
}

struct mixedOrder {
  SupportedOpertaions operation;
  AggregatedOrder[] swapOrders;
  AggregatedBorrowOrder[] borrowOrders;
}

struct Transfer {
  eaddress to;
  euint32 amount;
  address token;
}
// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.24;

import "./contracts_Lynx_interfaces_ITradeIncentivizerV1.sol";
import "./contracts_Lynx_interfaces_IPoolAccountantV1.sol";
import "./contracts_Lynx_Lex_LexCommon.sol";
import "./contracts_Lynx_interfaces_IInterestRateModel.sol";
import "./contracts_Lynx_interfaces_IFundingRateModel.sol";

/**
 * @title PoolAccountantStorage
 * @notice Storage contract for the pool accountant
 */
abstract contract PoolAccountantStorage is
  LexCommon,
  IPoolAccountantFunctionality
{
  address public tradeIncentivizer;
  uint256 public maxGainF; // 900% PnL (10x)

  /////////////////////////////////////////////
  /////////// LexFees storage slots ///////////
  /////////////////////////////////////////////

  IFundingRateModel public frm;
  uint256 public fundingRateMax;

  uint256 public liquidationThresholdF; // -90% (of collateral)
  uint256 public liquidationFeeF; // 5% (of collateral after fees)
  uint256 public lexPartF; // FRACTION_SCALE

  mapping(uint256 => int256) public pairTotalRatioOiToP;

  // Funding surplus/deficit in the pool
  int256 public realizedFundingSurplusDeficit;
  
  // pairIndex => info
  mapping(uint256 => PairFunding) public pairFunding;

  // trader => pairIndex => trade index => info
  mapping(bytes32 => TradeInitialAccFees) public tradeInitialAccFees;

  // trader => pairIndex => index => interest accumulated
  mapping(bytes32 => uint256) public tradeAccInterest; // Accrued interest for a specific trade and not yet paid

  // Current open interests for each pair
  mapping(uint256 => PairOpenInterest) public openInterestInPair;

  uint256 public minOpenFee; // Underlying decimals - this is the default value if not set on the pair nor the group level

  /////////////////////////////////////////////
  //////////// Debts storage slots ////////////
  /////////////////////////////////////////////

  IInterestRateModel public irm;

  uint256 public totalBorrows;
  uint256 public borrowIndex;
  uint256 public accrualBlockTimestamp;
  uint256 public totalInterest;

  uint256 public interestShare;

  mapping(uint256 => uint256) public pairBorrows;
  mapping(uint256 => uint256) public groupBorrows;

  uint256 public interestShareFactor; // FRACTION_SCALE
  uint256 public borrowRateMax;

  uint256 public maxTotalBorrows;

  uint256 public maxVirtualUtilization; // Percentage mantissa (85%) (PRECISION SCALE)

  /////////////////////////////////////////////
  ///////// PairsGroups storage slots /////////
  /////////////////////////////////////////////

  uint256 internal constant MIN_LEVERAGE = (1 * LEVERAGE_SCALE) / 2; // 0.5X
  uint256 internal constant MAX_LEVERAGE = 1000 * LEVERAGE_SCALE; // 1000X

  uint256 public pairsCount;
  uint256 public groupsCount;
  uint256 public feesCount;

  mapping(uint16 => Pair) public pairs;
  mapping(uint16 => Group) public groups;
  mapping(uint16 => Fee) public fees;

  uint16[] public supportedPairIds;
  uint16[] public supportedGroupIds;
  uint16[] public supportedFeeIds;

  mapping(uint256 => int256) public tradersPairGains; // Gains and losses in pair (traders accumulated gains and losses)

  /////////////////////////////////////////////
  ///////////// Base storage slots ////////////
  /////////////////////////////////////////////

  ILexPoolV1 public lexPool;

  /////////////////////////////////////////////
  ///////////// More funding slots ////////////
  /////////////////////////////////////////////
  
  // Stores the total amount of funding reserves in the pool.
  uint256 public fundingShare;

  // Fraction to take as protocol funding share
  uint256 public fundingShareFactor;

  function initializePoolAccountantStorage(
    ILexPoolV1 _lexPool,
    ITradingFloorV1 _tradingFloor
  ) internal {
    initializeLexCommon(_tradingFloor, _lexPool.underlying());
    require(address(lexPool) == address(0), "Initialized");
    lexPool = _lexPool;
  }
}
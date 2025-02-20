// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.24;

import "./contracts_Lynx_interfaces_LexErrors.sol";
import "./contracts_Lynx_interfaces_ILexPoolV1.sol";
import "./contracts_Lynx_interfaces_IInterestRateModel.sol";
import "./contracts_Lynx_interfaces_IFundingRateModel.sol";
import "./contracts_Lynx_interfaces_TradingEnumsV1.sol";

interface PoolAccountantStructs {
  // @note To be used for passing information in function calls
  struct PositionRegistrationParams {
    uint256 collateral;
    uint32 leverage;
    bool long;
    uint64 openPrice;
    uint64 tp;
  }

  struct PairFunding {
    // Slot 0
    int256 accPerOiLong; // 32 bytes -- Underlying Decimals
    // Slot 1
    int256 accPerOiShort; // 32 bytes -- Underlying Decimals
    // Slot 2
    uint256 lastUpdateTimestamp; // 32 bytes
  }

  struct TradeInitialAccFees {
    // Slot 0
    uint256 borrowIndex; // 32 bytes
    // Slot 1
    int256 funding; // 32 bytes -- underlying units -- Underlying Decimals
  }

  struct PairOpenInterest {
    // Slot 0
    uint256 long; // 32 bytes -- underlying units -- Dynamic open interest for long positions
    // Slot 1
    uint256 short; // 32 bytes -- underlying units -- Dynamic open interest for short positions
  }

  // This struct is not kept in storage
  struct PairFromTo {
    string from;
    string to;
  }

  struct Pair {
    // Slot 0
    uint16 id; // 02 bytes
    uint16 groupId; // 02 bytes
    uint16 feeId; // 02 bytes
    uint32 minLeverage; // 04 bytes
    uint32 maxLeverage; // 04 bytes
    uint32 maxBorrowF; // 04 bytes -- FRACTION_SCALE (5)
    // Slot 1
    uint256 maxPositionSize; // 32 bytes -- underlying units
    // Slot 2
    uint256 maxGain; // 32 bytes -- underlying units
    // Slot 3
    uint256 maxOpenInterest; // 32 bytes -- Underlying units
    // Slot 4
    uint256 maxSkew; // 32 bytes -- underlying units
    // Slot 5
    uint256 minOpenFee; // 32 bytes -- underlying units. MAX_UINT means use the default group level value
    // Slot 6
    uint256 minPerformanceFee; // 32 bytes -- underlying units
  }

  struct Group {
    // Slot 0
    uint16 id; // 02 bytes
    uint32 minLeverage; // 04 bytes
    uint32 maxLeverage; // 04 bytes
    uint32 maxBorrowF; // 04 bytes -- FRACTION_SCALE (5)
    // Slot 1
    uint256 maxPositionSize; // 32 bytes (Underlying units)
    // Slot 2
    uint256 minOpenFee; // 32 bytes (Underlying uints). MAX_UINT means use the default global level value
  }

  struct Fee {
    // Slot 0
    uint16 id; // 02 bytes
    uint32 openFeeF; // 04 bytes -- FRACTION_SCALE (5) (Fraction of leveraged pos)
    uint32 closeFeeF; // 04 bytes -- FRACTION_SCALE (5) (Fraction of leveraged pos)
    uint32 performanceFeeF; // 04 bytes -- FRACTION_SCALE (5) (Fraction of performance)
  }
}

interface PoolAccountantEvents is PoolAccountantStructs {
  event PairAdded(
    uint256 indexed id,
    string indexed from,
    string indexed to,
    Pair pair
  );
  event PairUpdated(uint256 indexed id, Pair pair);

  event GroupAdded(uint256 indexed id, string indexed groupName, Group group);
  event GroupUpdated(uint256 indexed id, Group group);

  event FeeAdded(uint256 indexed id, string indexed name, Fee fee);
  event FeeUpdated(uint256 indexed id, Fee fee);

  event TradeInitialAccFeesStored(
    bytes32 indexed positionId,
    uint256 borrowIndex,
    // uint256 rollover,
    int256 funding
  );

  event AccrueFunding(
    uint256 indexed pairId,
    int256 valueLong,
    int256 valueShort
  );

  event ProtocolFundingShareAccrued(
    uint16 indexed pairId,
    uint256 protocolFundingShare
  );
  // event AccRolloverFeesStored(uint256 pairIndex, uint256 value);

  event FeesCharged(
    bytes32 indexed positionId,
    address indexed trader,
    uint16 indexed pairId,
    PositionRegistrationParams positionRegistrationParams,
    //        bool long,
    //        uint256 collateral, // Underlying Decimals
    //        uint256 leverage,
    int256 profitPrecision, // PRECISION
    uint256 interest,
    int256 funding, // Underlying Decimals
    uint256 closingFee,
    uint256 tradeValue
  );

  event PerformanceFeeCharging(
    bytes32 indexed positionId,
    uint256 performanceFee
  );

  event MaxOpenInterestUpdated(uint256 pairIndex, uint256 maxOpenInterest);

  event AccrueInterest(
    uint256 cash,
    uint256 totalInterestNew,
    uint256 borrowIndexNew,
    uint256 interestShareNew
  );

  event Borrow(
    uint256 indexed pairId,
    uint256 borrowAmount,
    uint256 newTotalBorrows
  );

  event Repay(
    uint256 indexed pairId,
    uint256 repayAmount,
    uint256 newTotalBorrows
  );
}

interface IPoolAccountantFunctionality is
  PoolAccountantStructs,
  PoolAccountantEvents,
  LexErrors,
  TradingEnumsV1
{
  function setTradeIncentivizer(address _tradeIncentivizer) external;

  function setMaxGainF(uint256 _maxGainF) external;

  function setFrm(IFundingRateModel _frm) external;

  function setMinOpenFee(uint256 min) external;

  function setLexPartF(uint256 partF) external;

  function setFundingRateMax(uint256 maxValue) external;

  function setLiquidationThresholdF(uint256 threshold) external;

  function setLiquidationFeeF(uint256 fee) external;

  function setIrm(IInterestRateModel _irm) external;

  function setIrmHard(IInterestRateModel _irm) external;

  function setInterestShareFactor(uint256 factor) external;
  
  function setFundingShareFactor(uint256 factor) external;

  function setBorrowRateMax(uint256 rate) external;

  function setMaxTotalBorrows(uint256 maxBorrows) external;

  function setMaxVirtualUtilization(uint256 _maxVirtualUtilization) external;

  function resetTradersPairGains(uint256 pairId) external;

  function addGroup(Group calldata _group) external;

  function updateGroup(Group calldata _group) external;

  function addFee(Fee calldata _fee) external;

  function updateFee(Fee calldata _fee) external;

  function addPair(Pair calldata _pair) external;

  function addPairs(Pair[] calldata _pairs) external;

  function updatePair(Pair calldata _pair) external;

  function readAndZeroReserves()
    external
    returns (uint256 accumulatedInterestShare,
             uint256 accFundingShare);

  function registerOpenTrade(
    bytes32 positionId,
    address trader,
    uint16 pairId,
    uint256 collateral,
    uint32 leverage,
    bool long,
    uint256 tp,
    uint256 openPrice
  ) external returns (uint256 fee, uint256 lexPartFee);

  function registerCloseTrade(
    bytes32 positionId,
    address trader,
    uint16 pairId,
    PositionRegistrationParams calldata positionRegistrationParams,
    uint256 closePrice,
    PositionCloseType positionCloseType
  )
    external
    returns (
      uint256 closingFee,
      uint256 tradeValue,
      int256 profitPrecision,
      uint finalClosePrice
    );

  function registerUpdateTp(
    bytes32 positionId,
    address trader,
    uint16 pairId,
    uint256 collateral,
    uint32 leverage,
    bool long,
    uint256 openPrice,
    uint256 oldTriggerPrice,
    uint256 triggerPrice
  ) external;

  // function registerUpdateSl(
  //     address trader,
  //     uint256 pairIndex,
  //     uint256 index,
  //     uint256 collateral,
  //     uint256 leverage,
  //     bool long,
  //     uint256 openPrice,
  //     uint256 triggerPrice
  // ) external returns (uint256 fee);

  function accrueInterest()
    external
    returns (
      uint256 totalInterestNew,
      uint256 interestShareNew,
      uint256 borrowIndexNew
    );

  // Limited only for the LexPool
  function accrueInterest(
    uint256 availableCash
  )
    external
    returns (
      uint256 totalInterestNew,
      uint256 interestShareNew,
      uint256 borrowIndexNew
    );

  function getTradeClosingValues(
    bytes32 positionId,
    uint16 pairId,
    PositionRegistrationParams calldata positionRegistrationParams,
    uint256 closePrice,
    bool isLiquidation
  )
    external
    returns (
      uint256 tradeValue, // Underlying Decimals
      uint256 safeClosingFee,
      int256 profitPrecision,
      uint256 interest,
      int256 funding
    );

  function getTradeLiquidationPrice(
    bytes32 positionId,
    uint16 pairId,
    uint256 openPrice, // PRICE_SCALE (8)
    uint256 tp,
    bool long,
    uint256 collateral, // Underlying Decimals
    uint32 leverage
  )
    external
    returns (
      uint256 // PRICE_SCALE (8)
    );

  function calcTradeDynamicFees(
    bytes32 positionId,
    uint16 pairId,
    bool long,
    uint256 collateral,
    uint32 leverage,
    uint256 openPrice,
    uint256 tp
  ) external returns (uint256 interest, int256 funding);

  function unrealizedFunding() external view returns (int256);

  function totalBorrows() external view returns (uint256);

  function interestShare() external view returns (uint256);
  
  function fundingShare() external view returns (uint256);

  function totalReservesView() external view returns (uint256);

  function borrowsAndInterestShare()
    external
    view
    returns (uint256 totalBorrows, uint256 totalInterestShare);

  function pairTotalOpenInterest(
    uint256 pairIndex
  ) external view returns (int256);

  function pricePnL(
    uint256 pairId,
    uint256 price
  ) external view returns (int256);

  function getAllSupportedPairIds() external view returns (uint16[] memory);

  function getAllSupportedGroupsIds() external view returns (uint16[] memory);

  function getAllSupportedFeeIds() external view returns (uint16[] memory);
}

interface IPoolAccountantV1 is IPoolAccountantFunctionality {
  function totalBorrows() external view returns (uint256);

  function maxTotalBorrows() external view returns (uint256);

  function pairBorrows(uint256 pairId) external view returns (uint256);

  function groupBorrows(uint256 groupId) external view returns (uint256);

  function pairMaxBorrow(uint16 pairId) external view returns (uint256);

  function groupMaxBorrow(uint16 groupId) external view returns (uint256);

  function lexPool() external view returns (ILexPoolV1);

  function maxGainF() external view returns (uint256);

  function interestShareFactor() external view returns (uint256);
  
  function fundingShareFactor() external view returns (uint256);

  function frm() external view returns (IFundingRateModel);

  function irm() external view returns (IInterestRateModel);

  function pairs(uint16 pairId) external view returns (Pair memory);

  function groups(uint16 groupId) external view returns (Group memory);

  function fees(uint16 feeId) external view returns (Fee memory);

  function openInterestInPair(
    uint pairId
  ) external view returns (PairOpenInterest memory);

  function minOpenFee() external view returns (uint256);

  function liquidationThresholdF() external view returns (uint256);

  function liquidationFeeF() external view returns (uint256);

  function lexPartF() external view returns (uint256);

  function tradersPairGains(uint256 pairId) external view returns (int256);

  function calcBorrowAmount(
    uint256 collateral,
    uint256 leverage,
    bool long,
    uint256 openPrice,
    uint256 tp
  ) external pure returns (uint256);
}
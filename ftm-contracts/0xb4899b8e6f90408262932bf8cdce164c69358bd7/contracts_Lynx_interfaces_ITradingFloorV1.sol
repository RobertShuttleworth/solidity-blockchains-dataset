// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.24;

import "./contracts_Lynx_interfaces_TradingFloorStructsV1.sol";
import "./contracts_Lynx_interfaces_IPoolAccountantV1.sol";
import "./contracts_Lynx_interfaces_ILexPoolV1.sol";

interface ITradingFloorV1Functionality is TradingFloorStructsV1 {
  function supportNewSettlementAsset(
    address _asset,
    address _lexPool,
    address _poolAccountant
  ) external;

  function getPositionTriggerInfo(
    bytes32 _positionId
  )
    external
    view
    returns (
      PositionPhase positionPhase,
      uint64 timestamp,
      uint16 pairId,
      bool long,
      uint32 spreadReductionF
    );

  function getPositionPortalInfo(
    bytes32 _positionId
  )
    external
    view
    returns (
      PositionPhase positionPhase,
      uint64 inPhaseSince,
      address positionTrader
    );

  function storePendingPosition(
    OpenOrderType _orderType,
    PositionRequestIdentifiers memory _requestIdentifiers,
    PositionRequestParams memory _requestParams,
    uint32 _spreadReductionF
  ) external returns (bytes32 positionId);

  function setOpenedPositionToMarketClose(
    bytes32 _positionId,
    uint64 _minPrice,
    uint64 _maxPrice
  ) external;

  function cancelPendingPosition(
    bytes32 _positionId,
    OpenOrderType _orderType,
    uint feeFraction
  ) external;

  function cancelMarketCloseForPosition(
    bytes32 _positionId,
    CloseOrderType _orderType,
    uint feeFraction
  ) external;

  function updatePendingPosition_openLimit(
    bytes32 _positionId,
    uint64 _minPrice,
    uint64 _maxPrice,
    uint64 _tp,
    uint64 _sl
  ) external;

  function openNewPosition_market(
    bytes32 _positionId,
    uint64 assetEffectivePrice,
    uint256 feeForCancellation
  ) external;

  function openNewPosition_limit(
    bytes32 _positionId,
    uint64 assetEffectivePrice,
    uint256 feeForCancellation
  ) external;

  function closeExistingPosition_Market(
    bytes32 _positionId,
    uint64 assetPrice,
    uint64 effectivePrice
  ) external;

  function closeExistingPosition_Limit(
    bytes32 _positionId,
    LimitTrigger limitTrigger,
    uint64 assetPrice,
    uint64 effectivePrice
  ) external;

  // Manage open trade
  function updateOpenedPosition(
    bytes32 _positionId,
    PositionField updateField,
    uint64 fieldValue,
    uint64 effectivePrice
  ) external;

  // Fees
  function collectFee(address _asset, FeeType _feeType, address _to) external;
}

interface ITradingFloorV1 is ITradingFloorV1Functionality {
  function PRECISION() external pure returns (uint);

  // *** Views ***

  function pairTradersArray(
    address _asset,
    uint _pairIndex
  ) external view returns (address[] memory);

  function generatePositionHashId(
    address settlementAsset,
    address trader,
    uint16 pairId,
    uint32 index
  ) external pure returns (bytes32 hashId);

  // *** Public Storage addresses ***

  function lexPoolForAsset(address asset) external view returns (ILexPoolV1);

  function poolAccountantForAsset(
    address asset
  ) external view returns (IPoolAccountantV1);

  function registry() external view returns (address);

  // *** Public Storage params ***

  function positionsById(bytes32 id) external view returns (Position memory);

  function positionIdentifiersById(
    bytes32 id
  ) external view returns (PositionIdentifiers memory);

  function positionLimitsInfoById(
    bytes32 id
  ) external view returns (PositionLimitsInfo memory);

  function triggerPricesById(
    bytes32 id
  ) external view returns (PositionTriggerPrices memory);

  function pairTradersInfo(
    address settlementAsset,
    address trader,
    uint pairId
  ) external view returns (PairTraderInfo memory);

  function spreadReductionsP(uint) external view returns (uint);

  function maxSlF() external view returns (uint);

  function maxTradesPerPair() external view returns (uint);

  function maxSanityProfitF() external view returns (uint);

  function feesMap(
    address settlementAsset,
    FeeType feeType
  ) external view returns (uint256);
}
// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.24;

import "./contracts_Lynx_Lex_PoolAccountant_Debts.sol";

/**
 * @title AccountantFees
 * @notice This contract is responsible for positions' fees.
 * The contract calculate the funding, the borrow amount, open and close fees.
 * Also the contract calculate the value of a position considering all of its fees.
 */
abstract contract AccountantFees is Debts {
  function setFrm(IFundingRateModel _frm) external onlyAdmin {
    frm = _frm;
    emit AddressUpdated(PoolAccountantAddressesEnum.frm, address(_frm));
  }

  function setMinOpenFee(uint256 min) external onlyAdmin {
    minOpenFee = min;
    emit NumberUpdated(PoolAccountantV1NumbersEnum.minOpenFee, min);
  }

  function setLexPartF(uint256 partF) external onlyAdmin {
    lexPartF = partF;
    emit NumberUpdated(PoolAccountantV1NumbersEnum.lexPartF, partF);
  }

  function setFundingRateMax(uint256 maxValue) external onlyAdmin {
    fundingRateMax = maxValue;
    emit NumberUpdated(PoolAccountantV1NumbersEnum.fundingRateMax, maxValue);
  }

  function setLiquidationThresholdF(uint256 threshold) external onlyAdmin {
    require(threshold <= FRACTION_SCALE, "!LiqThreshold");
    liquidationThresholdF = threshold;
    emit NumberUpdated(
      PoolAccountantV1NumbersEnum.liquidationThresholdF,
      threshold
    );
  }

  function setLiquidationFeeF(uint256 fee) external onlyAdmin {
    require(fee <= FRACTION_SCALE, "!LiqFee");
    liquidationFeeF = fee;
    emit NumberUpdated(PoolAccountantV1NumbersEnum.liquidationFeeF, fee);
  }

  // Hooks
  function updateRealizedFunding(int256 valueChange) internal {
    realizedFundingSurplusDeficit += valueChange;
  }

  // ***** Views *****

  function calcAccrueFundingValues(
    uint16 pairId
  ) public view returns (bool freshened, 
                         int256 valueLong, 
                         int256 valueShort,
                         uint256 protocolFundingShare) {
    PairFunding memory f = pairFunding[pairId];
    valueLong = f.accPerOiLong;
    valueShort = f.accPerOiShort;

    uint256 timediff = block.timestamp - f.lastUpdateTimestamp;
    if (timediff == 0) {
      // Already fresh
      return (false, valueLong, valueShort, 0);
    }

    PairOpenInterest memory openInterest = openInterestInPair[pairId];
    uint256 maxPairOpenInterest = pairs[pairId].maxOpenInterest;

    uint256 fundingRate = frm.getFundingRate(
      pairId,
      openInterest.long,
      openInterest.short,
      maxPairOpenInterest
    );
    if (fundingRate > fundingRateMax)
      revert CapError(CapType.FUNDING_RATE_MAX, fundingRate);

    int256 indexLongChange;
    int256 indexShortChange;
    (indexLongChange, indexShortChange, protocolFundingShare) = fundingIndicesCalculation(
      openInterest.long,
      openInterest.short,
      fundingRate,
      timediff
    );
    valueLong += indexLongChange;
    valueShort += indexShortChange;

    return (true, valueLong, valueShort, protocolFundingShare);
  }

  function fundingIndicesCalculation(
    uint256 _oiLong,
    uint256 _oiShort,
    uint256 fundingRate,
    uint256 timeDiff
  ) public view returns (int256 indexLongChange, 
                         int256 indexShortChange,
                         uint256 protocolFundingShare) {
    if (_oiLong == _oiShort) return (0, 0, 0);

    bool isLongLarger = _oiLong > _oiShort;
    (uint256 oiLarge, uint256 oiSmall) = isLongLarger
      ? (_oiLong, _oiShort)
      : (_oiShort, _oiLong);

    uint simpleFundingRate = fundingRate * timeDiff;

    uint fundingPaidByLargeScaled = simpleFundingRate * oiLarge;
    uint256 valueLargePay = 0;
    uint256 valueSmallReceive = 0;

    // Logically it's fundingPaidByLargeScaled / oiLarge;
    valueLargePay = simpleFundingRate * ACCURACY_IMPROVEMENT_SCALE; 

    if (oiSmall != 0) { 
      // Take a factor of the funding paid by large pool.
      // Factor is scaled by PRECISION so dividing.
      uint protocolFundingShareScaled = fundingPaidByLargeScaled * fundingShareFactor 
                                        / PRECISION;
      // protocolFundingShareScaled is also scaled by PRECISION (oiLarge) 
      // so we divide again to represent token amount.
      protocolFundingShare = protocolFundingShareScaled / PRECISION;

      // Small pool recieves the funding paid by the large pool 
      // minus protocol funding share.
      valueSmallReceive =
      ((fundingPaidByLargeScaled - protocolFundingShareScaled) * 
      ACCURACY_IMPROVEMENT_SCALE) / oiSmall;
    } else {
      // If small pool is empty, there's no one to recieve the funding, 
      // take all funding share to the lex funding reserve.
      protocolFundingShare = fundingPaidByLargeScaled / PRECISION;
    }

    indexLongChange = isLongLarger
      ? int256(valueLargePay)
      : -int256(valueSmallReceive);
    indexShortChange = isLongLarger
      ? -int256(valueSmallReceive)
      : int256(valueLargePay);
  }

  function getTradeLiquidationPriceView(
    uint256 openPrice, // PRICE_SCALE (8)
    bool long,
    uint256 collateral, // Underlying Decimals
    uint256 leverage,
    uint256 interest, // Underlying Decimals
    int256 funding, // Underlying Decimals
    uint256 closingFee
  ) public view returns (uint256) {
    // PRICE_SCALE (8)
    int256 liqPriceDistance = (((int256(openPrice) *
      (int256((collateral * liquidationThresholdF) / FRACTION_SCALE) -
        int256(interest) -
        funding -
        int256(closingFee))) / int256(collateral)) * int256(LEVERAGE_SCALE)) /
      int256(leverage);

    int256 liqPrice = long
      ? int256(openPrice) - liqPriceDistance
      : int256(openPrice) + liqPriceDistance;

    return liqPrice > 0 ? uint256(liqPrice) : 0;
  }

  function calcProfitPrecision(
    uint256 openPrice,
    uint256 targetPrice,
    bool long,
    uint256 leverage
  ) internal pure returns (int256) {
    int256 sOpenPrice = int256(openPrice); // Signed
    int256 sTargetPrice = int256(targetPrice); // Signed
    int256 pricesDiff = long
      ? sTargetPrice - sOpenPrice
      : sOpenPrice - sTargetPrice;

    return
      (pricesDiff * int256((PRECISION * leverage) / LEVERAGE_SCALE)) /
      sOpenPrice;
  }

  function calcBorrowAmount(
    uint256 collateral,
    uint256 leverage,
    bool long,
    uint256 openPrice,
    uint256 tp
  ) public pure returns (uint256) {
    int256 profitPrecision = calcProfitPrecision(openPrice, tp, long, leverage);
    if (profitPrecision <= 0) return 0;

    return (uint256(profitPrecision) * collateral) / PRECISION;
  }

  function getTradeInterest(
    bytes32 positionId,
    uint256 borrowAmount
  ) public returns (uint256) {
    // Underlying Decimals
    (, , uint256 borrowIndexNew) = accrueInterest();
    TradeInitialAccFees memory t = tradeInitialAccFees[positionId];
    uint256 accumulated = tradeAccInterest[positionId];

    return
      getTradeInterestPure(
        t.borrowIndex,
        borrowIndexNew,
        borrowAmount,
        accumulated
      );
  }

  // Assumes accrued interest
  function restartTradeInterest(
    bytes32 positionId,
    uint256 oldBorrowAmount
  ) internal {
    tradeAccInterest[positionId] = getTradeInterest(
      positionId,
      oldBorrowAmount
    );
    tradeInitialAccFees[positionId].borrowIndex = borrowIndex;
  }

  function getTradeInterestPure(
    uint256 tradeBorrowIndex,
    uint256 currentBorrowIndex,
    uint256 borrowAmount, // Underlying Decimals
    uint256 alreadyAccumulated
  ) public pure returns (uint256) {
    return
      ((borrowAmount * (currentBorrowIndex - tradeBorrowIndex)) / PRECISION) +
      alreadyAccumulated;
  }

  // Funding fee value

  function getTradeFunding(
    bytes32 positionId,
    uint16 pairId,
    bool long,
    uint256 collateral, // Underlying Decimals
    uint32 leverage
  )
    public
    returns (
      int256 // Underlying Decimals | Positive => Fee, Negative => Reward
    )
  {
    (int256 pendingLong, int256 pendingShort, ) = accrueFunding(pairId);

    int256 tradeFundingIndex = tradeInitialAccFees[positionId].funding;

    return
      getTradeFundingPure(
        tradeFundingIndex,
        long ? pendingLong : pendingShort,
        collateral,
        leverage
      );
  }

  function getTradeFundingPure(
    int256 accFundingPerOi,
    int256 endAccFundingPerOi,
    uint256 collateral, // Underlying Decimals
    uint256 leverage
  )
    public
    pure
    returns (
      int256 // Underlying Decimals | Positive => Fee, Negative => Reward
    )
  {
    return
      ((endAccFundingPerOi - accFundingPerOi) * int256(collateral * leverage)) /
      int256(LEVERAGE_SCALE * PRECISION * ACCURACY_IMPROVEMENT_SCALE);
  }

  function calcClosingFee(
    uint16 pairId,
    uint256 collateral,
    uint32 leverage
  ) public view returns (uint256) {
    uint256 leveragedPosition = calculateLeveragedPosition(
      collateral,
      leverage
    );
    uint256 closingFeeFraction = pairCloseFeeF(pairId);
    return calculateFeeInternal(leveragedPosition, closingFeeFraction);
  }

  function calcPerformanceFee(
    uint16 pairId,
    uint256 collateral,
    int256 profitPrecision
  ) public view returns (uint256) {
    uint256 minPerformanceFee = pairMinPerformanceFee(pairId);
    uint256 performanceFee = 0;
    int256 profit = (int256(collateral) * profitPrecision) / int256(PRECISION);

    if (0 < profit) {
      performanceFee = calculateFeeInternal(
        uint256(profit),
        pairPerformanceFeeF(pairId)
      );
      return
        performanceFee < minPerformanceFee ? minPerformanceFee : performanceFee;
    }

    // when the profit is negative: if loss is greater than minPerformanceFee than return 0, if not than return the diff between minPerformanceFee and the loss
    uint256 loss = uint256(-profit);
    if (loss > minPerformanceFee) {
      return 0;
    }
    return minPerformanceFee - loss;
  }

  function calculateLexPartFee(uint256 fee) internal view returns (uint256) {
    return (fee * lexPartF) / FRACTION_SCALE;
  }

  function getTradeValueView(
    uint256 collateral, // Underlying Decimals
    int256 profitPrecision, // PRECISION
    uint256 interest, // Underlying Decimals
    int256 funding, // Underlying Decimals
    uint256 closingFee, // Underlying Decimals
    bool liquidation
  ) public view returns (uint256) {
    // Underlying Decimals
    int256 value = int256(collateral) +
      (int256(collateral) * profitPrecision) /
      int256(PRECISION) -
      int256(interest) -
      funding -
      int256(closingFee);

    if (liquidation) {
      value =
        (value * int256(FRACTION_SCALE - liquidationFeeF)) /
        int256(FRACTION_SCALE); // Taking liquidation fee
    }

    return value > 0 ? uint256(value) : 0;
  }

  // *****
  // Vault Fees interface
  // *****

  function getTradeLiquidationPrice(
    bytes32 positionId,
    uint16 pairId,
    uint256 openPrice, // PRICE_SCALE (8)
    uint256 tp,
    bool long,
    uint256 collateral, // Underlying Decimals
    uint32 leverage
  )
    public
    override
    returns (
      uint256 // PRICE_SCALE (8)
    )
  {
    (uint256 interest, int256 funding) = calcTradeDynamicFees(
      positionId,
      pairId,
      long,
      collateral,
      leverage,
      openPrice,
      tp
    );

    uint256 closingFee = calcClosingFee(pairId, collateral, leverage);

    return
      getTradeLiquidationPriceView(
        openPrice,
        long,
        collateral,
        leverage,
        interest,
        funding,
        closingFee
      );
  }

  function storeTradeInitialAccFees(
    bytes32 positionId,
    uint16 pairId,
    bool long
  ) internal {
    (, , uint256 borrowIndexNew) = accrueInterest();
    (int256 accPerOiLong, int256 accPerOiShort, ) = accrueFunding(pairId);

    TradeInitialAccFees storage t = tradeInitialAccFees[positionId];
    tradeAccInterest[positionId] = 0;

    t.borrowIndex = borrowIndexNew;

    t.funding = long ? accPerOiLong : accPerOiShort;

    emit TradeInitialAccFeesStored(positionId, t.borrowIndex, t.funding);
  }

  function calcSafeClosingFee(
    uint256 collateral,
    int256 funding,
    uint256 closingFee
  ) internal pure returns (uint256) {
    uint256 collateralAfterFunding = funding > int256(collateral)
      ? 0
      : uint256(int256(collateral) - funding);

    return
      closingFee < collateralAfterFunding ? closingFee : collateralAfterFunding;
  }

  function calcTradeDynamicFees(
    bytes32 positionId,
    uint16 pairId,
    bool long,
    uint256 collateral,
    uint32 leverage,
    uint256 openPrice,
    uint256 tp
  ) public returns (uint256 interest, int256 funding) {
    uint256 borrowAmount = calcBorrowAmount(
      collateral,
      leverage,
      long,
      openPrice,
      tp
    );
    interest = getTradeInterest(positionId, borrowAmount);
    funding = getTradeFunding(positionId, pairId, long, collateral, leverage);
  }

  function updateStateForClosingTrade(
    bytes32 positionId,
    address trader,
    uint16 pairId,
    PositionRegistrationParams calldata positionRegistrationParams,
    uint256 closePrice,
    bool isLiquidation
  )
    internal
    returns (uint256 tradeValue, uint256 safeClosingFee, int256 profitPrecision)
  {
    uint256 interest;
    int256 funding;

    (
      tradeValue,
      safeClosingFee,
      profitPrecision,
      interest,
      funding
    ) = getTradeClosingValues(
      positionId,
      pairId,
      positionRegistrationParams,
      closePrice,
      isLiquidation
    );

    repayInterest(interest);
    updateRealizedFunding(funding);

    emit FeesCharged(
      positionId,
      trader,
      pairId,
      positionRegistrationParams,
      profitPrecision,
      interest,
      funding,
      safeClosingFee,
      tradeValue
    );
  }

  function getTradeClosingValues(
    bytes32 positionId,
    uint16 pairId,
    PositionRegistrationParams calldata positionRegistrationParams,
    uint256 closePrice,
    bool isLiquidation
  )
    public
    override
    returns (
      uint256 tradeValue, // Underlying Decimals
      uint256 safeClosingFee,
      int256 profitPrecision,
      uint256 interest,
      int256 funding
    )
  {
    accrueInterest();
    accrueFunding(pairId);

    (interest, funding) = calcTradeDynamicFees(
      positionId,
      pairId,
      positionRegistrationParams.long,
      positionRegistrationParams.collateral,
      positionRegistrationParams.leverage,
      positionRegistrationParams.openPrice,
      positionRegistrationParams.tp
    );

    uint256 closingFeeUnsafe = calcClosingFee(
      pairId,
      positionRegistrationParams.collateral,
      positionRegistrationParams.leverage
    );

    profitPrecision = calcProfitPrecision(
      positionRegistrationParams.openPrice,
      closePrice,
      positionRegistrationParams.long,
      positionRegistrationParams.leverage
    );

    uint256 performanceFee = calcPerformanceFee(
      pairId,
      positionRegistrationParams.collateral,
      profitPrecision
    );

    emit PerformanceFeeCharging(positionId, performanceFee);
    closingFeeUnsafe += performanceFee;

    tradeValue = getTradeValueView(
      positionRegistrationParams.collateral,
      profitPrecision,
      interest,
      funding,
      closingFeeUnsafe,
      isLiquidation
    );

    safeClosingFee = calcSafeClosingFee(
      positionRegistrationParams.collateral,
      funding,
      closingFeeUnsafe
    );
  }

  function calculateFeeInternal(
    uint256 amount,
    uint256 feeFraction
  ) internal pure returns (uint256) {
    return (amount * feeFraction) / FRACTION_SCALE;
  }

  // *****
  // Interface internals
  // *****
  function updateOpenInterestInPairInternal(
    uint16 _pairId,
    uint256 _leveragedPos,
    bool _open,
    bool _long,
    uint256 price
  ) internal {
    accrueFunding(_pairId);

    Pair memory pair = pairs[_pairId];
    PairOpenInterest storage openInterestPair = openInterestInPair[_pairId];

    uint256 openInterestPrior = _long
      ? openInterestPair.long
      : openInterestPair.short;

    uint256 newOpenInterest = _open
      ? openInterestPrior + _leveragedPos
      : openInterestPrior - _leveragedPos;

    if (_open) {
      if (newOpenInterest > pair.maxOpenInterest) {
        revert CapError(CapType.MAX_OPEN_INTEREST, newOpenInterest);
      }

      uint256 absSkew = calcAbsoluteSkew(
        openInterestPair.long,
        openInterestPair.short,
        _long,
        _leveragedPos
      );
      if (absSkew > pair.maxSkew) {
        revert CapError(CapType.MAX_ABS_SKEW, absSkew);
      }
    }

    if (_long) {
      openInterestPair.long = newOpenInterest;
    } else {
      openInterestPair.short = newOpenInterest;
    }
    int256 oiChange = (_open == _long)
      ? int256(_leveragedPos)
      : -int256(_leveragedPos);

    updateTotalRatioOiToP(_pairId, oiChange, price);
  }

  function updateTotalRatioOiToP(
    uint256 pairId,
    int256 openInterestChange,
    uint256 price // The price on opening the trade
  ) private returns (int256 newValue) {
    int256 oldValue = pairTotalRatioOiToP[pairId];
    newValue =
      oldValue +
      ((openInterestChange * int256(PRECISION * ACCURACY_IMPROVEMENT_SCALE)) /
        int256(price));
    pairTotalRatioOiToP[pairId] = newValue;
  }

  function effectiveEntryPrice(
    int256 totalOpenInterest,
    int256 totalRatioOiToP
  ) internal pure returns (int256) {
    if (0 == totalRatioOiToP) {
      return 0;
    }
    return
      (totalOpenInterest *
        int256(ACCURACY_IMPROVEMENT_SCALE) *
        int256(PRECISION * ACCURACY_IMPROVEMENT_SCALE)) / totalRatioOiToP;
  }

  function effectiveEntryPrice(uint256 pairId) internal view returns (int256) {
    return
      effectiveEntryPrice(
        pairTotalOpenInterest(pairId),
        pairTotalRatioOiToP[pairId]
      );
  }

  function pricePnL(
    int256 totalOpenInterest,
    int256 effEntryPrice,
    uint256 price
  ) internal pure returns (int256) {
    if (0 == effEntryPrice) {
      return 0;
    }
    int256 iPnlExtraScale = int256(ACCURACY_IMPROVEMENT_SCALE);
    return
      (totalOpenInterest *
        iPnlExtraScale *
        (int256(price) * iPnlExtraScale - effEntryPrice)) /
      effEntryPrice /
      iPnlExtraScale;
  }

  function pricePnL(
    uint256 pairId,
    uint256 price
  ) public view returns (int256) {
    int256 totalOI = pairTotalOpenInterest(pairId);
    int256 effPrice = effectiveEntryPrice(totalOI, pairTotalRatioOiToP[pairId]);
    return pricePnL(totalOI, effPrice, price);
  }

  function calcAbsoluteSkew(
    uint256 openInterestLong,
    uint256 openInterestShort,
    bool additionIsLong,
    uint256 additionOpenInterest
  ) public pure returns (uint256) {
    int256 skew = int256(openInterestLong) - int256(openInterestShort);
    int256 signedAddition = additionIsLong
      ? int256(additionOpenInterest)
      : -int256(additionOpenInterest);
    skew += signedAddition;
    return skew > 0 ? uint256(skew) : uint256(-skew);
  }

  // *****
  // Private logic
  // *****

  // Acc funding fees (store right before trades opened / closed and fee % update)
  function accrueFunding(
    uint16 pairId
  ) public override returns (int256 valueLong, int256 valueShort, 
                            uint256 protocolFundingShare) {
    bool freshened;
    (freshened, valueLong, valueShort, protocolFundingShare) = 
    calcAccrueFundingValues(pairId);

    if (freshened) {
      pairFunding[pairId] = PairFunding({
        accPerOiLong: valueLong,
        accPerOiShort: valueShort,
        lastUpdateTimestamp: block.timestamp
      });

      // Accumulate the protocol funding share
      fundingShare += protocolFundingShare;

      emit AccrueFunding(pairId, valueLong, valueShort);
      emit ProtocolFundingShareAccrued(pairId, protocolFundingShare);
    }
  }

  // *****
  // Extra external views
  // *****

  /**
   * Retrieve the acc per open interest for the long side of a pair
   */
  function getAccFundingLong(uint256 pairIndex) external view returns (int256) {
    return pairFunding[pairIndex].accPerOiLong;
  }
  /**
   * Retrieve the acc per open interest for the short side of a pair
   */
  function getAccFundingShort(
    uint256 pairIndex
  ) external view returns (int256) {
    return pairFunding[pairIndex].accPerOiShort;
  }

  /**
   * Retrieve the last updated timestamp for a pair funding
   */
  function getAccFundingUpdateBlock(
    uint256 pairIndex
  ) external view returns (uint256) {
    return pairFunding[pairIndex].lastUpdateTimestamp;
  }

  /**
   * Retrieve the recorded borrow index for a position when opened
   */
  function getTradeInitialAccBorrowIndex(
    bytes32 positionId
  ) external view returns (uint256) {
    return tradeInitialAccFees[positionId].borrowIndex;
  }

  function getTradeInitialAccFundingPerOi(
    bytes32 positionId
  ) external view returns (int256) {
    return tradeInitialAccFees[positionId].funding;
  }

  /**
   * Retreive the total open interest of a pair
   */
  function pairTotalOpenInterest(
    uint256 pairIndex
  ) public view override returns (int256) {
    PairOpenInterest memory oi = openInterestInPair[pairIndex];
    return int256(oi.long) - int256(oi.short);
  }

  /**
   * Generate the position id hash using the trader address, the pairId and the trade index
   */
  function generatePositionHashId(
    address settlementAsset,
    address trader,
    uint16 pairId,
    uint32 index
  ) public pure returns (bytes32 hashId) {
    hashId = keccak256(
      abi.encodePacked(settlementAsset, trader, pairId, index)
    );
  }
}
// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.24;

import "./contracts_Lynx_Lex_PoolAccountant_AccountantFees.sol";
import "./contracts_Lynx_Lex_PoolAccountant_PoolAccountantStorage.sol";
import "./contracts_Lynx_Lex_PoolAccountant_PoolAccountantProxy.sol";

/**
 * @title PoolAccountantV1
 * @dev The main contract for the Pool Accountant, holds the trade logic, in charge of managing the caps, fees and loans.
 */
contract PoolAccountantV1 is AccountantFees {
  // ***** Initialization Functions *****

  /**
   * @notice Part of the Proxy mechanism
   */
  function _become(PoolAccountantProxy proxy) external {
    //        require(
    //            msg.sender == proxy.admin(),
    //            "!proxy.admin"
    //        );
    require(proxy._acceptImplementation() == 0, "fail");
  }

  /**
   * @notice Used to initialize this contract, can only be called once
   * @dev This is needed because of the Proxy-Upgrade paradigm.
   */
  function initialize(
    ILexPoolV1 _lexPool,
    ITradingFloorV1 _tradingFloor
  ) external {
    initializePoolAccountantStorage(_lexPool, _tradingFloor);
  }

  // ***** Admin Functions *****

  function setTradeIncentivizer(address _tradeIncentivizer) external onlyAdmin {
    tradeIncentivizer = _tradeIncentivizer;
    emit AddressUpdated(
      PoolAccountantAddressesEnum.incentivizer,
      address(_tradeIncentivizer)
    );
  }

  function setMaxGainF(uint256 _maxGainF) external onlyAdmin {
    maxGainF = _maxGainF;
    emit NumberUpdated(PoolAccountantV1NumbersEnum.maxGainF, _maxGainF);
  }

  // ***** Lex Pool Interaction Functions *****

  /**
   * System accounting mechanism. Allows the pool to send the proper amount of reserves and prevents
   * double spending by zeroing the storage value after reading it.
   * @dev The pool should always act upon the returned value and not
   * @return accumulatedInterestShare The amount of interest share at the moment of calling this function (underlying scale)
   */
  function readAndZeroReserves()
    external
    returns (uint256 accumulatedInterestShare, 
             uint256 accFundingShare)
  {
    require(msg.sender == address(lexPool), "!Pool");
    // Read
    accumulatedInterestShare = interestShare;
    accFundingShare = fundingShare;

    // Reduce the amount withdrawn from realized funding
    updateRealizedFunding(-int256(accFundingShare));

    // Zero
    interestShare = 0;
    fundingShare = 0;
  }

  // ***** Trade Registration Functions *****

  /**
   * TradingFloor-Lex connection function to indicate that a position is being opened.
   * @dev The opening fees are being determined in this contract
   */
  function registerOpenTrade(
    bytes32 positionId,
    address trader,
    uint16 pairId,
    uint256 collateral,
    uint32 leverage,
    bool long,
    uint256 tp,
    uint256 openPrice
  )
    external
    override
    onlyTradingFloor
    returns (uint256 openFee, uint256 lexPartFee)
  {
    verifyTradersPairGains(pairId);
    uint256 leveragedPosition = verifyLeveragedPosition(
      pairId,
      collateral,
      leverage
    );

    verifyMaxPercentProfit(openPrice, tp, leverage, long);

    (openFee, lexPartFee) = verifyOpenFee(pairId, leveragedPosition);

    uint256 collateralAfterFee = collateral - openFee;
    verifyPerformanceFee(pairId, collateralAfterFee);

    uint256 leveragedPositionAfterFee = calculateLeveragedPosition(
      collateralAfterFee,
      leverage
    );

    updateOpenInterestInPairInternal(
      pairId,
      leveragedPositionAfterFee,
      true,
      long,
      openPrice
    );

    (uint256 newTotalBorrows, uint256 newTotalReserves) = borrow(
      pairId,
      calcBorrowAmount(collateralAfterFee, leverage, long, openPrice, tp)
    );
    verifyUtilizationForTraders(
      newTotalBorrows,
      newTotalReserves,
      unrealizedFunding()
    );
    storeTradeInitialAccFees(positionId, pairId, long); // Must be called after accrue interest (called on borrow)

    incentivizerInformOpen(
      positionId,
      trader,
      pairId,
      collateral,
      leverage,
      long,
      openFee
    );
  }

  /**
   * TradingFloor-Lex connection function to indicate that a position is being closed.
   * @dev The closing fees and final values of the positions are being determined in this contract
   */
  function registerCloseTrade(
    bytes32 positionId,
    address trader,
    uint16 pairId,
    PositionRegistrationParams calldata positionRegistrationParams,
    uint256 closePrice,
    PositionCloseType positionCloseType
  )
    external
    override
    onlyTradingFloor
    returns (
      uint256 closingFee,
      uint256 tradeValue,
      int256 profitPrecision,
      uint finalClosingPrice
    )
  {
    bool isLiquidation = positionCloseType == PositionCloseType.LIQ;
    finalClosingPrice = isLiquidation
      ? getTradeLiquidationPrice(
        positionId,
        pairId,
        positionRegistrationParams.openPrice,
        positionRegistrationParams.tp,
        positionRegistrationParams.long,
        positionRegistrationParams.collateral,
        positionRegistrationParams.leverage
      )
      : adjustClosePrice(
        closePrice,
        positionRegistrationParams.tp,
        positionRegistrationParams.long
      );

    uint256 leveragedPosition = calculateLeveragedPosition(
      positionRegistrationParams.collateral,
      positionRegistrationParams.leverage
    );

    updateOpenInterestInPairInternal(
      pairId,
      leveragedPosition,
      false,
      positionRegistrationParams.long,
      positionRegistrationParams.openPrice
    );

    repay( // Accrues interest
      pairId,
      calcBorrowAmount(
        positionRegistrationParams.collateral,
        positionRegistrationParams.leverage,
        positionRegistrationParams.long,
        positionRegistrationParams.openPrice,
        positionRegistrationParams.tp
      )
    );

    // 1. Calculate net PnL (after all closing fees)
    (tradeValue, closingFee, profitPrecision) = updateStateForClosingTrade( // Accrues interest
      positionId,
      trader,
      pairId,
      positionRegistrationParams,
      finalClosingPrice,
      isLiquidation
    );

    updateTradersPairGains(
      pairId,
      positionRegistrationParams.collateral,
      profitPrecision
    );

    incentivizerInformClose(
      positionId,
      trader,
      pairId,
      positionRegistrationParams.collateral,
      positionRegistrationParams.leverage,
      positionRegistrationParams.long,
      closingFee,
      profitPrecision,
      tradeValue
    );
  }

  /**
   * TradingFloor-Lex connection function to indicate that the TP of a position is updated.
   */
  function registerUpdateTp(
    bytes32 positionId,
    address, // trader
    uint16 pairId,
    uint256 collateral,
    uint32 leverage,
    bool long,
    uint256 openPrice,
    uint256 oldTriggerPrice,
    uint256 triggerPrice
  ) external override onlyTradingFloor {
    verifyMaxPercentProfit(openPrice, triggerPrice, leverage, long);

    uint256 borrowOld = calcBorrowAmount(
      collateral,
      leverage,
      long,
      openPrice,
      oldTriggerPrice
    );

    uint256 borrowNew = calcBorrowAmount(
      collateral,
      leverage,
      long,
      openPrice,
      triggerPrice
    );

    if (borrowNew > borrowOld) {
      (uint256 newTotalBorrows, uint256 newTotalReserves) = borrow(
        pairId,
        borrowNew - borrowOld
      );
      verifyUtilizationForTraders(
        newTotalBorrows,
        newTotalReserves,
        unrealizedFunding()
      );
    } else if (borrowNew < borrowOld) {
      repay(pairId, borrowOld - borrowNew);
    }

    restartTradeInterest(positionId, borrowOld);
  }

  // function registerUpdateSl(
  //     address trader,
  //     uint256 pairIndex,
  //     uint256 index,
  //     uint256 collateral,
  //     uint256 leverage,
  //     bool long,
  //     uint256 openPrice,
  //     uint256 triggerPrice
  // ) external override returns (uint256 fee) {}

  // ***** Trade Adjustment And Verifications Functions *****

  /**
   * Utility function to ensure that position will not get closed by a price higher/lower (long/short) than
   * their set TP value
   * @return The proper closing price
   */
  function adjustClosePrice(
    uint256 closePrice,
    uint256 tp,
    bool long
  ) public pure returns (uint256) {
    if (long) {
      return closePrice > tp ? tp : closePrice;
    }
    return closePrice < tp ? tp : closePrice;
  }

  /**
   * Validity function to ensure that the leveraged position fits withing the size limits set for both the pair and
   * the group.
   * @return leveragedPosition The "actual" size of the position (collateral * leverage)
   */
  function verifyLeveragedPosition(
    uint16 pairIndex,
    uint256 collateral,
    uint32 leverage
  ) public view returns (uint256 leveragedPosition) {
    leveragedPosition = calculateLeveragedPosition(collateral, leverage);

    Pair memory pair = pairs[pairIndex];
    if (leverage > pair.maxLeverage) {
      revert CapError(CapType.MAX_LEVERAGE, leverage);
    } else if (leverage < pair.minLeverage) {
      revert CapError(CapType.MIN_LEVERAGE, leverage);
    } else if (leveragedPosition > pair.maxPositionSize) {
      revert CapError(CapType.MAX_POS_SIZE_PAIR, leveragedPosition);
    }

    Group memory group = groups[pair.groupId];
    if (leverage > group.maxLeverage) {
      revert CapError(CapType.MAX_LEVERAGE, leverage);
    } else if (leverage < group.minLeverage) {
      revert CapError(CapType.MIN_LEVERAGE, leverage);
    } else if (leveragedPosition > group.maxPositionSize) {
      revert CapError(CapType.MAX_POS_SIZE_GROUP, leveragedPosition);
    }
  }

  /**
   * Validity function to ensure that the given position's opening fee is high enough.
   */
  function verifyOpenFee(
    uint16 pairIndex,
    uint256 leveragedPosition
  ) public view returns (uint256 openFee, uint256 lexPartFee) {
    openFee = calculateFeeInternal(leveragedPosition, pairOpenFeeF(pairIndex));
    if (openFee < pairMinOpenFee(pairIndex))
      revert CapError(CapType.MIN_OPEN_FEE, openFee);
    lexPartFee = calculateLexPartFee(openFee);
  }

  /**
   * Validity function to ensure the collateral of the position is enough to pay the minimum performance fee.
   */
  function verifyPerformanceFee(
    uint16 pairIndex,
    uint256 collateral
  ) public view {
    if (collateral <= pairMinPerformanceFee(pairIndex)) {
      revert CapError(CapType.MIN_PERFORMANCE_FEE, collateral);
    }
  }

  /**
   * Validity function to ensure that the potential profit of a given position does not breach the set limits.
   */
  function verifyMaxPercentProfit(
    uint256 openPrice,
    uint256 targetPrice,
    uint256 leverage,
    bool long
  ) public view {
    int256 potentialProfitPrecision = calcProfitPrecision(
      openPrice,
      targetPrice,
      long,
      leverage
    );

    uint256 maxGainPrecision = (maxGainF * PRECISION) / FRACTION_SCALE;

    if (potentialProfitPrecision > int256(maxGainPrecision)) {
      // Here, potentialProfitPrecision must be > 0 so we can convert it to unsigned
      revert CapError(
        CapType.MAX_POTENTIAL_GAIN,
        uint256(potentialProfitPrecision)
      );
    }
  }

  // ***** Incentivizer Interactions Functions *****

  /**
   * Informs the TradeIncentivizer about the opening of a position.
   * @dev This function will swallow any revert coming from the 'TradeIncentivizer' in order to never
   * prevent a position from being opened
   */
  function incentivizerInformOpen(
    bytes32 positionId,
    address trader,
    uint16 pairId,
    uint256 collateral,
    uint32 leverage,
    bool long,
    uint256 openFee
  ) internal {
    ITradeIncentivizerV1 incentivizer = ITradeIncentivizerV1(tradeIncentivizer);
    if (address(incentivizer) == address(0)) return;

    try
      incentivizer.informTradeOpen(
        positionId,
        trader,
        pairId,
        collateral,
        leverage,
        long,
        openFee
      )
    {} catch {}
  }

  /**
   * Informs the TradeIncentivizer about the closure of a position.
   * @dev This function will swallow any revert coming from the 'TradeIncentivizer' in order to never
   * prevent a position from being closed
   */
  function incentivizerInformClose(
    bytes32 positionId,
    address trader,
    uint16 pairId,
    uint256 collateral,
    uint32 leverage,
    bool long,
    uint256 closeFee,
    int256 profitPrecision,
    uint256 finalValue
  ) internal {
    ITradeIncentivizerV1 incentivizer = ITradeIncentivizerV1(tradeIncentivizer);
    if (address(incentivizer) == address(0)) return;

    try
      incentivizer.informTradeClose(
        positionId,
        trader,
        pairId,
        collateral,
        leverage,
        long,
        closeFee,
        profitPrecision,
        finalValue
      )
    {} catch {}
  }
}
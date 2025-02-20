// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.24;

import "./contracts_Lynx_Lex_PoolAccountant_AccountantPairGroups.sol";

/**
 * @title Debts
 * @notice This contract is responsible for debts.
 *         The contracts registers the raw loans and calculate the interest that should be paid by each user.
 */
abstract contract Debts is AccountantPairGroups {
  /**
   * Set the IRM (accrue interest before actually replacing the IRM)
   */
  function setIrm(IInterestRateModel _irm) external onlyAdmin {
    accrueInterest();
    irm = _irm;
    emit AddressUpdated(PoolAccountantAddressesEnum.irm, address(irm));
  }

  /**
   * Set the IRM (without acrruing interest before)
   */
  function setIrmHard(IInterestRateModel _irm) external onlyAdmin {
    irm = _irm;
    emit AddressUpdated(PoolAccountantAddressesEnum.irm, address(irm));
  }

  function setInterestShareFactor(uint256 factor) external onlyAdmin {
    accrueInterest();
    interestShareFactor = factor;
    emit NumberUpdated(PoolAccountantV1NumbersEnum.interestShareFactor, factor);
  }

  function setFundingShareFactor(uint256 factor) external onlyAdmin {
    fundingShareFactor = factor;
    emit NumberUpdated(PoolAccountantV1NumbersEnum.fundingShareFactor, factor);
  }

  function setBorrowRateMax(uint256 rate) external onlyAdmin {
    borrowRateMax = rate;
    emit NumberUpdated(PoolAccountantV1NumbersEnum.borrowRateMax, rate);
  }

  function setMaxTotalBorrows(uint256 maxBorrows) external onlyAdmin {
    maxTotalBorrows = maxBorrows;
    emit NumberUpdated(PoolAccountantV1NumbersEnum.maxTotalBorrows, maxBorrows);
  }

  function setMaxVirtualUtilization(
    uint256 _maxVirtualUtilization
  ) external onlyAdmin {
    require(
      _maxVirtualUtilization <= 1 * PRECISION,
      "Illegal maxVirtualUtilization"
    );
    maxVirtualUtilization = _maxVirtualUtilization;
    emit NumberUpdated(
      PoolAccountantV1NumbersEnum.maxVirtualUtilization,
      _maxVirtualUtilization
    );
  }

  /**
   * Verify that the utilization is not over the max utilization allowed for traders
   */
  function verifyUtilizationForTraders(
    uint256 _totalBorrows,
    uint256 _totalReserves,
    int256 _unrealizedFunding
  ) public view {
    uint256 utilization = lexPool.currentVirtualUtilization(
      _totalBorrows,
      _totalReserves,
      _unrealizedFunding
    );
    if (utilization > maxVirtualUtilization) {
      revert CapError(CapType.MAX_VIRTUAL_UTILIZATION, utilization);
    }
  }

  /**
   * Accrue the interest accumulated given the available cash (since the last time the system accrued interest)
   */
  function accrueInterest(
    uint256 availableCash
  )
    external
    override
    onlyLexPool
    returns (
      uint256 totalInterestNew,
      uint256 interestShareNew,
      uint256 borrowIndexNew
    )
  {
    return accrueInterestInternal(availableCash);
  }

  /**
   * Accrue the interest accumulated (and read the available cash) (since the last time the system accrued interest)
   */
  function accrueInterest()
    public
    override
    returns (
      uint256 totalInterestNew,
      uint256 interestShareNew,
      uint256 borrowIndexNew
    )
  {
    return accrueInterestInternal(virtualBalance());
  }

  function accrueInterestInternal(
    uint256 availableCash
  )
    internal
    returns (
      uint256 totalInterestNew,
      uint256 interestShareNew,
      uint256 borrowIndexNew
    )
  {
    bool freshened;
    (
      freshened,
      totalInterestNew,
      borrowIndexNew,
      interestShareNew
    ) = calcAccrueInterestValues(availableCash);

    if (freshened) {
      totalInterest = totalInterestNew;
      borrowIndex = borrowIndexNew;
      interestShare = interestShareNew;
      accrualBlockTimestamp = block.timestamp;

      emit AccrueInterest(
        availableCash,
        totalInterestNew,
        borrowIndexNew,
        interestShareNew
      );
    }
  }

  /**
   * Inner function for accruing interest
   */
  function calcAccrueInterestValues()
    public
    view
    returns (
      bool freshened,
      uint256 totalInterestNew,
      uint256 borrowIndexNew,
      uint256 interestShareNew
    )
  {
    return calcAccrueInterestValues(virtualBalance());
  }

  function calcUtilization(
    uint256 availableCash,
    uint256 borrows
  ) private pure returns (uint256) {
    if (borrows == 0) return 0;
    if (availableCash == 0) return type(uint256).max;
    return (borrows * PRECISION) / availableCash;
  }

  /**
   * Inner function for accruing interest
   */
  function calcAccrueInterestValues(
    uint256 availableCash
  )
    public
    view
    returns (
      bool freshened,
      uint256 totalInterestNew,
      uint256 borrowIndexNew,
      uint256 interestShareNew
    )
  {
    uint256 currentBlockTimestamp = block.timestamp;
    uint256 accrualBlockTimestampPrior = accrualBlockTimestamp;
    // WARNING: What happens for subsecond blocks? Is there any problem here?
    if (accrualBlockTimestampPrior == currentBlockTimestamp) {
      return (false, totalInterest, borrowIndex, interestShare);
    }

    uint256 borrowsPrior = totalBorrows;
    uint256 interestSharePrior = interestShare;
    uint256 borrowIndexPrior = borrowIndex;

    uint256 borrowRate = irm.getBorrowRate(
      calcUtilization(availableCash, borrowsPrior)
    );
    if (borrowRate > borrowRateMax) {
      revert CapError(CapType.BORROW_RATE_MAX, borrowRate);
    }
    uint256 timeDelta = currentBlockTimestamp - accrualBlockTimestampPrior;

    uint256 simpleInterestFactor = borrowRate * timeDelta;
    uint256 interestAccumulated = (simpleInterestFactor * borrowsPrior) /
      PRECISION;
    interestShareNew =
      interestSharePrior +
      ((interestShareFactor * interestAccumulated) / PRECISION);
    borrowIndexNew = borrowIndexPrior + simpleInterestFactor;

    totalInterestNew = totalInterest + interestAccumulated;
    freshened = true;
  }

  function borrow(
    uint16 pairId,
    uint256 amount
  ) internal returns (uint256 newTotalBorrows, uint256 newTotalReserves) {
    (, newTotalReserves, ) = accrueInterest();

    uint256 oldPairBorrows = pairBorrows[pairId];
    uint256 newPairBorrows = oldPairBorrows + amount;
    if (newPairBorrows > pairMaxBorrow(pairId)) {
      revert CapError(CapType.MAX_BORROW_PAIR, newPairBorrows);
    }

    uint16 groupId = pairs[pairId].groupId;

    uint256 oldGroupBorrows = groupBorrows[groupId];
    uint256 newGroupBorrows = oldGroupBorrows + amount;
    if (newGroupBorrows > groupMaxBorrow(groupId)) {
      revert CapError(CapType.MAX_BORROW_GROUP, newGroupBorrows);
    }

    uint256 oldTotalBorrows = totalBorrows;
    newTotalBorrows = oldTotalBorrows + amount;

    if (newTotalBorrows > maxTotalBorrows)
      revert CapError(CapType.MAX_TOTAL_BORROW, newTotalBorrows);

    pairBorrows[pairId] = newPairBorrows;
    groupBorrows[groupId] = newGroupBorrows;
    totalBorrows = newTotalBorrows;

    emit Borrow(pairId, amount, newTotalBorrows);
  }

  function repay(uint16 pairId, uint256 amount) internal {
    accrueInterest();

    totalBorrows -= amount;
    groupBorrows[pairs[pairId].groupId] -= amount;
    pairBorrows[pairId] -= amount;

    emit Repay(pairId, amount, totalBorrows);
  }

  function repayInterest(uint256 amount) internal {
    uint256 totalInterestOld = totalInterest;
    if (amount > totalInterestOld) {
      totalInterest = 0;
    } else {
      totalInterest -= amount;
    }
  }

  /**
   * Retrieve the unrealized funding value (which is the negative of the realized function surplus deficit)
   */
  function unrealizedFunding() public view returns (int256) {
    return -realizedFundingSurplusDeficit;
  }

  /**
   * Retrieve the total borrows and the interest share
   */
  function borrowsAndInterestShare()
    public
    view
    returns (uint256 borrows, uint256 totalInterestShare)
  {
    return (totalBorrows, interestShare);
  }

  /**
   * Retrieve the total reserves
   */
  function totalReservesView() public view returns (uint256) {
    return interestShare;
  }

  function virtualBalance() internal view override returns (uint256) {
    return
      lexPool.virtualBalanceForUtilization(
        totalReservesView(),
        unrealizedFunding()
      );
  }
}
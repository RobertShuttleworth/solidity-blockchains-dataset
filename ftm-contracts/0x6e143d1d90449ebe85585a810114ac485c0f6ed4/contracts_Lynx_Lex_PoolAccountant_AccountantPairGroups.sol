// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.24;

import "./contracts_Lynx_Lex_PoolAccountant_PoolAccountantBase.sol";

/**
 * @title AccountantPairGroups
 * @notice This is a utility contract that register all of the pairs and the groups with their specific properties.
 */
abstract contract AccountantPairGroups is PoolAccountantBase {
  string internal constant emptyString = "";

  // ***** Events *****

  event TradersPairGainsReset(uint indexed pairId);

  // ***** Modifiers *****

  modifier groupListed(uint16 _groupId) {
    require(isGroupListed(_groupId), "GROUP_NOT_LISTED");
    _;
  }

  modifier feeListed(uint16 _feeId) {
    require(isFeeListed(_feeId), "FEE_NOT_LISTED");
    _;
  }

  modifier pairListed(uint16 _pairId) {
    require(isPairListed(_pairId), "PAIR_NOT_LISTED");
    _;
  }

  modifier groupOk(Group calldata _group) {
    require(
      _group.minLeverage >= MIN_LEVERAGE &&
        _group.maxLeverage <= MAX_LEVERAGE &&
        _group.minLeverage <= _group.maxLeverage,
      "WRONG_LEVERAGES"
    );
    require(_group.maxBorrowF <= 1 * PRECISION, "Wrong maxBorrowF");
    _;
  }

  modifier pairOk(Pair calldata _pair) {
    require(isGroupListed(_pair.groupId), "Wrong group");
    require(isFeeListed(_pair.feeId), "Wrong fee");
    require(
      _pair.minLeverage >= MIN_LEVERAGE &&
        _pair.maxLeverage <= MAX_LEVERAGE &&
        _pair.minLeverage <= _pair.maxLeverage,
      "WRONG_LEVERAGES"
    );
    require(_pair.maxBorrowF <= 1 * PRECISION, "Wrong maxBorrowF");
    require(_pair.maxSkew <= _pair.maxOpenInterest, "MaxSkew<=MaxIO");
    _;
  }

  modifier feeOk(Fee calldata _fee) {
    //        require(_fee.openFeeF > 0 && _fee.closeFeeF > 0, "WRONG_FEES");
    require(_fee.id > 0, "WRONG_FEE_ID");
    _;
  }

  // ***** Views *****

  /**
   * Retrieve the max borrow of a group
   */
  function groupMaxBorrow(uint16 groupId) public view returns (uint256) {
    uint256 selfCurrentBalance = virtualBalance();
    return (groups[groupId].maxBorrowF * selfCurrentBalance) / FRACTION_SCALE;
  }

  /**
   * Retrieve the max borrow of a pair
   */
  function pairMaxBorrow(uint16 pairId) public view returns (uint256) {
    uint256 selfCurrentBalance = virtualBalance();
    return (pairs[pairId].maxBorrowF * selfCurrentBalance) / FRACTION_SCALE;
  }

  /**
   * Retrieve the open fee (fraction) of a pair
   */
  function pairOpenFeeF(uint16 _pairId) public view returns (uint32) {
    return fees[pairs[_pairId].feeId].openFeeF;
  }

  /**
   * Retrieve the close fee (fraction) of a pair
   */
  function pairCloseFeeF(uint16 _pairId) public view returns (uint32) {
    return fees[pairs[_pairId].feeId].closeFeeF;
  }

  /**
   * Reterieve the performance fee (fraction) of a pair
   */
  function pairPerformanceFeeF(uint16 _pairId) public view returns (uint32) {
    return fees[pairs[_pairId].feeId].performanceFeeF;
  }

  function pairMinPerformanceFee(
    uint16 _pairId
  ) internal view returns (uint256) {
    return pairs[_pairId].minPerformanceFee;
  }

  /**
   * Retrieve the minimum open fee (fraction) of a pair
   */
  function pairMinOpenFee(uint16 _pairId) public view returns (uint256) {
    Pair memory pair = pairs[_pairId];
    if (pair.minOpenFee < type(uint256).max) {
      return pair.minOpenFee;
    }

    Group memory group = groups[pair.groupId];
    if (group.minOpenFee < type(uint256).max) {
      return group.minOpenFee;
    }

    return minOpenFee;
  }

  /**
   * Verify that the accumulated of the traders for the pairId are not over the max gain value
   */
  function verifyTradersPairGains(uint16 pairId) public view {
    int256 currentGains = tradersPairGains[pairId];
    if (currentGains > 0 && currentGains >= int256(pairs[pairId].maxGain)) {
      // maxGain is uint256 - symbolizes gains. So if we are here then currentGainLoss > 0;
      revert CapError(CapType.MAX_ACCUMULATED_GAINS, uint256(currentGains));
    }
  }

  /**
   * Utility function to retrieve the array of pair ids that are supported by the system
   */
  function getAllSupportedPairIds() external view returns (uint16[] memory) {
    return supportedPairIds;
  }

  /**
   * Utility function to retrieve the array of group ids that are supported by the system
   */
  function getAllSupportedGroupsIds() external view returns (uint16[] memory) {
    return supportedGroupIds;
  }

  /**
   * Utility function to retrieve the array of feed ids that are supported by the system
   */
  function getAllSupportedFeeIds() external view returns (uint16[] memory) {
    return supportedFeeIds;
  }

  // ***** Admin Functions *****

  /**
   * Reset the traders accumulated gain for a specific pair to zero
   */
  function resetTradersPairGains(uint256 pairId) external onlyAdmin {
    tradersPairGains[pairId] = 0;
    emit TradersPairGainsReset(pairId);
  }

  /**
   * Support a new group
   */
  function addGroup(Group calldata _group) external onlyAdmin groupOk(_group) {
    uint16 _id = _group.id;
    require(_id != 0, "INVALID_ID");
    require(!isGroupListed(_id), "GROUP_EXISTS");

    groups[_id] = _group;
    supportedGroupIds.push(_id);

    groupsCount++;

    emit GroupAdded(_id, emptyString, _group);
  }

  /**
   * Update the properties of a group
   */
  function updateGroup(
    Group calldata _group
  ) external onlyAdmin groupListed(_group.id) groupOk(_group) {
    groups[_group.id] = _group;
    emit GroupUpdated(_group.id, _group);
  }

  // Manage fees

  /**
   * Support a new fee type
   */
  function addFee(Fee calldata _fee) external onlyAdmin feeOk(_fee) {
    uint16 _id = _fee.id;
    require(_id != 0, "INVALID_ID");
    require(!isFeeListed(_id), "FEE_EXISTS");

    fees[_id] = _fee;
    supportedFeeIds.push(_fee.id);
    feesCount++;

    emit FeeAdded(_id, emptyString, _fee);
  }

  /**
   * Update the fee percentage of a fee di
   */
  function updateFee(
    Fee calldata _fee
  ) external onlyAdmin feeListed(_fee.id) feeOk(_fee) {
    fees[_fee.id] = _fee;
    emit FeeUpdated(_fee.id, _fee);
  }

  /**
   * Support a new pair
   */
  function addPair(Pair calldata _pair) external onlyAdmin {
    addPairInternal(_pair);
  }

  /**
   * Support a list of new pairs
   */
  function addPairs(Pair[] calldata _pairs) external onlyAdmin {
    for (uint256 i = 0; i < _pairs.length; i++) {
      addPairInternal(_pairs[i]);
    }
  }

  /**
   * Update the properties of a pair
   */
  function updatePair(
    Pair calldata _pair
  ) external pairOk(_pair) pairListed(_pair.id) onlyAdmin {
    accrueFunding(_pair.id);
    pairs[_pair.id] = _pair;
    emit PairUpdated(_pair.id, _pair);
  }

  // ***** Internal logic *****

  function updateTradersPairGains(
    uint256 pairIndex,
    uint256 collateral,
    int256 profitPrecision
  ) internal {
    int256 gains = (int256(collateral) * profitPrecision) / int256(PRECISION);
    tradersPairGains[pairIndex] += gains;
  }

  function addPairInternal(Pair calldata _pair) internal pairOk(_pair) {
    require(!isPairListed(_pair.id), "PAIR_EXISTS");

    pairs[_pair.id] = _pair;
    supportedPairIds.push(_pair.id);

    // Increase pair count
    pairsCount++;

    emit PairAdded(_pair.id, emptyString, emptyString, _pair);
  }

  // ***** Internal util views *****

  function isPairListed(uint16 pairId) private view returns (bool) {
    return pairs[pairId].id == pairId;
  }

  function isGroupListed(uint16 groupId) private view returns (bool) {
    return groups[groupId].id == groupId;
  }

  function isFeeListed(uint16 feeId) private view returns (bool) {
    return fees[feeId].id == feeId;
  }
}
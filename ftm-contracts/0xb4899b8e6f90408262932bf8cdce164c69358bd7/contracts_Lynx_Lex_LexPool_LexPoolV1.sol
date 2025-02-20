// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.24;

import "./openzeppelin_contracts_token_ERC20_IERC20.sol";
import "./openzeppelin_contracts_token_ERC20_utils_SafeERC20.sol";
import "./openzeppelin_contracts_utils_math_SafeCast.sol";

import "./contracts_Lynx_interfaces_ILexPoolV1.sol";
import "./contracts_Lynx_interfaces_IPoolAccountantV1.sol";
import "./contracts_Lynx_interfaces_IRegistryV1.sol";
import "./contracts_Lynx_Lex_LexCommon.sol";
import "./contracts_Lynx_Lex_LexPool_LexPoolStorage.sol";
import "./contracts_Lynx_Lex_LexPool_LexPoolProxy.sol";
import "./contracts_Lynx_interfaces_IAffiliationV1.sol";

/**
 * @title LexPoolV1
 * @dev The main contract for the Lex Pool, holds the liquidity and the logic for depositing and redeeming
 *      and for the epoch system.
 */
contract LexPoolV1 is LexPoolStorage, ILexPoolFunctionality, IAffiliationV1 {
  using SafeERC20 for IERC20;
  using SafeCast for uint256;
  using SafeCast for int256;

  // ***** Constants *****

  uint public constant SELF_UNIT_SCALE = 1e18;

  // ***** Modifiers *****

  modifier onlyLiquidityIntentsVerifier() {
    require(
      msg.sender == IRegistryV1(registry).liquidityIntentsVerifier(),
      "!LiquidityIntentsVerifier"
    );
    _;
  }

  // ***** Views *****

  /**
   * Calculates the beginning timestamp of the next epoch by rounding down to a round "duration" unit multiplication.
   * @return The timestamp in which the next epoch can start (seconds)
   */
  function calcNextEpochStartMin() public view returns (uint256) {
    uint256 duration = epochDuration;
    uint256 virtualEpochIndex = block.timestamp / duration;
    return (virtualEpochIndex + 1) * duration;
  }

  /**
   * @return The current underlying balance of this contract (underlying scale)
   */
  function currentBalanceInternal() public view returns (uint256) {
    return underlying.balanceOf(address(this));
  }

  /**
   * @return The current underlying balance of this contract to be used for exchange rate purposes (underlying scale)
   */
  function underlyingBalanceForExchangeRate() public view returns (uint256) {
    uint256 balance = currentBalanceInternal();
    uint256 pendingAmount = pendingDepositAmount;
    require(balance > pendingAmount, "Fatal error");
    return balance - pendingAmount;
  }

  /**
   * Calculates the amount that is available to be borrowed by reducing the GIVEN amounts and pending
   * amounts from the current ERC20 balance
   * @return The amount of underlying (in underlying scale) that is available to be borrowed
   */
  function virtualBalanceForUtilization(
    uint256 extraAmount, // sum of the amounts that are held by the contract but are not part of the available balance for utilization (such as interestShare and )
    int256 unrealizedFunding
  ) public view returns (uint256) {
    uint256 balance = currentBalanceInternal();
    uint subtractionFromUnrealizedFunding = unrealizedFunding < 0
      ? (-unrealizedFunding).toUint256()
      : 0;
    uint256 pendingAmount = pendingDepositAmount + pendingWithdrawalAmount;
    if (
      balance < pendingAmount + extraAmount + subtractionFromUnrealizedFunding
    ) return 0;
    return
      balance - pendingAmount - extraAmount - subtractionFromUnrealizedFunding;
  }

  /**
   * Calculates the amount that is available to be borrowed by reducing the CURRENT amounts and pending
   * amounts from the current ERC20 balance
   * @return The amount of underlying (in underlying scale) that is available to be borrowed
   */
  function virtualBalanceForUtilization() public view returns (uint256) {
    return
      virtualBalanceForUtilization(
        poolAccountant.totalReservesView(),
        poolAccountant.unrealizedFunding()
      );
  }

  /**
   * Calculates the utilization as a percentage of virtual borrows out the of the total available balance
   * by the GIVEN values.
   * @return The 'virtual' utilization, scaled by PRECISION
   */
  function currentVirtualUtilization(
    uint256 totalBorrows,
    uint256 interestShare,
    int256 unrealizedFunding
  ) public view returns (uint256) {
    if (totalBorrows == 0) {
      return 0;
    }
    uint256 virtualBalance = virtualBalanceForUtilization(
      interestShare,
      unrealizedFunding
    );
    if (virtualBalance == 0) return type(uint256).max;
    return (totalBorrows * PRECISION) / virtualBalance;
  }

  /**
   * Calculates the utilization as a percentage of virtual borrows out the of the total available balance
   * by the CURRENT values.
   * @return The 'virtual' utilization, scaled by PRECISION
   */
  function currentVirtualUtilization() public view returns (uint256) {
    (uint256 borrows, uint256 interestShare) = poolAccountant
      .borrowsAndInterestShare();
    int256 unrealizedFunding = poolAccountant.unrealizedFunding();
    return currentVirtualUtilization(borrows, interestShare, unrealizedFunding);
  }

  /**
   * @return true if the current utilization is less than a hundred
   */
  function isUtilizationForLPsValid() public view returns (bool) {
    uint256 utilization = currentVirtualUtilization();
    uint256 hundredPercent = 1 * PRECISION;
    return utilization <= hundredPercent;
  }

  /**
   * Utility function to underlying amount to its matching amount in Lex tokens by the current exchange rate
   */
  function underlyingAmountToOwnAmount(
    uint256 underlyingAmount
  ) public view returns (uint256 ownAmount) {
    ownAmount = underlyingAmountToOwnAmountInternal(
      currentExchangeRate,
      underlyingAmount
    );
  }

  /**
   * Utility function to retrieve the amount of depositors of a given epoch or a subsection of
   */
  function getDepositorsCount(uint256 epoch) external view returns (uint256) {
    return pendingDepositorsArr[epoch].length;
  }

  /**
   * Utility function to retrieve the amount of redeemers of a given epoch or a subsection of
   */
  function getRedeemersCount(uint256 epoch) external view returns (uint256) {
    return pendingRedeemersArr[epoch].length;
  }

  /**
   * Utility function to retrieve the array of depositors of a given epoch or a subsection of
   */
  function getDepositors(
    uint256 epoch,
    uint256 indexFrom,
    uint256 count
  ) external view returns (address[] memory depositors) {
    return getArrItems(pendingDepositorsArr[epoch], indexFrom, count);
  }

  /**
   * Utility function to retrieve the array of redeemers of a given epoch or a subsection of
   */
  function getRedeemers(
    uint256 epoch,
    uint256 indexFrom,
    uint256 count
  ) external view returns (address[] memory redeemers) {
    return getArrItems(pendingRedeemersArr[epoch], indexFrom, count);
  }

  // ***** Initialization functions *****

  /**
   * @notice Part of the Proxy mechanism
   */
  function _become(LexPoolProxy proxy) public {
    require(msg.sender == proxy.admin(), "!proxy.admin");
    require(proxy._acceptImplementation() == 0, "fail");
  }

  /**
   * @notice Used to initialize this contract, can only be called once
   * @dev This is needed because of the Proxy-Upgrade paradigm.
   */
  function initialize(
    ERC20 _underlying,
    ITradingFloorV1 _tradingFloor,
    uint _epochDuration
  ) external {
    initializeLexPoolStorage(_tradingFloor, _underlying, _epochDuration);
    currentExchangeRate = 10 ** underlyingDecimals;

    epochsDelayDeposit = 2;
    epochsDelayRedeem = 2;
    nextEpochStartMin = calcNextEpochStartMin();
  }

  // ***** Admin functions *****

  function setPoolAccountant(
    IPoolAccountantFunctionality _poolAccountant
  ) external onlyAdmin {
    require(address(_poolAccountant) != address(0), "InvalidAddress");

    poolAccountant = _poolAccountant;

    emit AddressUpdated(
      LexPoolAddressesEnum.poolAccountant,
      address(_poolAccountant)
    );
  }

  function setPnlRole(address pnl) external onlyAdmin {
    require(address(pnl) != address(0), "InvalidAddress");

    pnlRole = pnl;
    emit AddressUpdated(LexPoolAddressesEnum.pnlRole, address(pnl));
  }

  function setMaxExtraWithdrawalAmountF(uint256 maxExtra) external onlyAdmin {
    maxExtraWithdrawalAmountF = maxExtra;
    emit NumberUpdated(LexPoolNumbersEnum.maxExtraWithdrawalAmountF, maxExtra);
  }

  function setEpochsDelayDeposit(uint256 delay) external onlyAdmin {
    epochsDelayDeposit = delay;
    emit NumberUpdated(LexPoolNumbersEnum.epochsDelayDeposit, delay);
  }

  function setEpochsDelayRedeem(uint256 delay) external onlyAdmin {
    epochsDelayRedeem = delay;
    emit NumberUpdated(LexPoolNumbersEnum.epochsDelayRedeem, delay);
  }

  function setEpochDuration(uint256 duration) external onlyAdmin {
    epochDuration = duration;
    emit NumberUpdated(LexPoolNumbersEnum.epochDuration, duration);
  }

  function setMinDepositAmount(uint256 amount) external onlyAdmin {
    minDepositAmount = amount;
    emit NumberUpdated(LexPoolNumbersEnum.minDepositAmount, amount);
  }

  /**
   * Toggle the immediate deposit functionality - this way, no trigger is needed after requesting deposit
   */
  function toggleImmediateDepositAllowed() external onlyAdmin {
    immediateDepositAllowed = !immediateDepositAllowed;
    emit ImmediateDepositAllowedToggled(immediateDepositAllowed);
  }

  /**
   * Withdraw the reserves from the system
   * We accrue interest to maximize the amount of reserves that can be withdrawn
   */
  function reduceReserves(address _to) external onlyAdmin {
    require(
      msg.sender == IRegistryV1(registry).feesManagers(address(underlying)),
      "!feesManager"
    );
    poolAccountant.accrueInterest(virtualBalanceForUtilization());

    // Read interest and funding resreves and send them.
    (uint interestShare, uint256 totalFundingShare) = 
      poolAccountant.readAndZeroReserves();
    uint reservesToSend = interestShare + totalFundingShare;

    if (reservesToSend > 0) {
      underlying.safeTransfer(_to, reservesToSend);
    }

    // Emit event to notify how much was withdrawn 
    // from accumulated intereset and funding reserves.
    emit ReservesWithdrawn(_to, interestShare, totalFundingShare);
  }

  // ***** User interaction functions *****

  /**
   * User interaction to deposit to the pool in a single tx using the current exchange rate.
   * The 'immediateDepositAllowed' must be 'true' to allow this function to pass
   * We accrue interest before the deposit because the virtualBalanceForUtilization changes (the underlying balance changes)
   */
  function immediateDeposit(
    uint256 depositAmount,
    bytes32 domain,
    bytes32 referralCode
  ) external nonReentrant {
    require(immediateDepositAllowed, "!Allowed");

    if (depositAmount < minDepositAmount)
      revert CapError(CapType.MIN_DEPOSIT_AMOUNT, depositAmount);

    poolAccountant.accrueInterest(virtualBalanceForUtilization());

    address user = msg.sender;

    takeUnderlying(user, depositAmount);

    uint256 amountToMint = underlyingAmountToOwnAmount(depositAmount);
    _mint(user, amountToMint);

    emit ImmediateDeposit(user, depositAmount, amountToMint);
    emit LiquidityProvided(
      domain,
      referralCode,
      user,
      depositAmount,
      currentEpoch
    );
  }

  /**
   * Direct EOA interaction for requesting deposit
   */
  function requestDeposit(
    uint256 amount,
    uint256 minAmountOut,
    bytes32 domain,
    bytes32 referralCode
  ) external nonReentrant {
    require(!immediateDepositAllowed, "!Allowed");
    address user = msg.sender;
    requestDepositInternal(user, amount, minAmountOut, domain, referralCode);
  }

  /**
   * Intent based interaction for requesting deposit
   */
  function requestDepositViaIntent(
    address user,
    uint256 amount,
    uint256 minAmountOut,
    bytes32 domain,
    bytes32 referralCode
  ) external nonReentrant onlyLiquidityIntentsVerifier {
    require(!immediateDepositAllowed, "!Allowed");
    requestDepositInternal(user, amount, minAmountOut, domain, referralCode);
  }

  /**
   * User interaction to request to deposit to the pool in a two phases.
   * The request can be triggered after 'epochsDelayDeposit' epochs have passed
   * We don't accrue interest here becuase the virtualBalanceForUtilization doesn't change
   * as the underlying balance and the pendingDepositAmount changes cancel each other out.
   */
  function requestDepositInternal(
    address user,
    uint256 amount,
    uint256 minAmountOut,
    bytes32 domain,
    bytes32 referralCode
  ) internal {
    if (amount < minDepositAmount)
      revert CapError(CapType.MIN_DEPOSIT_AMOUNT, amount);

    uint256 epoch = currentEpoch + epochsDelayDeposit;
    require(pendingRedeems[epoch][user].amount == 0, "Redeem exists");
    takeUnderlying(user, amount);
    pendingDepositAmount += amount;

    PendingDeposit storage pendingDeposit = pendingDeposits[epoch][user];
    if (pendingDeposit.amount == 0) {
      // The first time for this user on this epoch
      // So this user is not yet in the array
      pendingDepositorsArr[epoch].push(user);
    }

    pendingDeposit.amount = pendingDeposit.amount + amount;
    pendingDeposit.minAmountOut = pendingDeposit.minAmountOut + minAmountOut;

    emit DepositRequest(user, amount, minAmountOut, epoch);
    emit LiquidityProvided(domain, referralCode, user, amount, epoch);
  }

  /**
   * Direct EOA interaction for requesting redeeming
   */
  function requestRedeem(
    uint256 amount,
    uint256 minAmountOut
  ) external nonReentrant {
    address user = msg.sender;
    requestRedeemInternal(user, amount, minAmountOut);
  }

  /**
   * Intent based interaction for requesting redeeming
   */
  function requestRedeemViaIntent(
    address user,
    uint256 amount,
    uint256 minAmountOut
  ) external nonReentrant onlyLiquidityIntentsVerifier {
    requestRedeemInternal(user, amount, minAmountOut);
  }

  /**
   * User interaction to request to redeem from the pool in a two phases.
   * The request can be triggered after 'epochsDelayRedeem' epochs have passed
   * Not like requestDeposit, here we have to accrue interest before the request because we do change the state:
   * the pendingWithdrawalAmount increases by the max amount that can be withdrawn (even though most of the time
   * the actual withdrawal will be less than the max amount that can be withdrawn).
   */
  function requestRedeemInternal(
    address user,
    uint256 amount,
    uint256 minAmountOut
  ) internal {
    uint256 epoch = currentEpoch + epochsDelayRedeem;
    require(pendingDeposits[epoch][user].amount == 0, "Exists deposit");

    poolAccountant.accrueInterest(virtualBalanceForUtilization());

    _transfer(user, address(this), amount);
    uint256 rate = currentExchangeRate;
    uint256 currentUnderlyingAmountOut = ownAmountToUnderlyingAmountInternal(
      rate,
      amount
    );

    require(
      minAmountOut <= currentUnderlyingAmountOut,
      "MinAmountOut too high"
    );
    uint256 maxUnderlyingAmountOut = (currentUnderlyingAmountOut *
      (FRACTION_SCALE + maxExtraWithdrawalAmountF)) / FRACTION_SCALE;

    pendingWithdrawalAmount += maxUnderlyingAmountOut;
    verifyUtilizationForLPs();

    PendingRedeem storage pendingRedeem = pendingRedeems[epoch][user];
    if (pendingRedeem.amount == 0) {
      // The first time for this user on this epoch
      // So this user is not yet in the array
      pendingRedeemersArr[epoch].push(user);
    }

    pendingRedeem.amount = pendingRedeem.amount + amount;
    pendingRedeem.minAmountOut = pendingRedeem.minAmountOut + minAmountOut;
    pendingRedeem.maxAmountOut =
      pendingRedeem.maxAmountOut +
      maxUnderlyingAmountOut;

    emit RedeemRequest(user, amount, minAmountOut, epoch);
  }

  /**
   * Allows "processing" of pending deposit requests that are due for the current epoch.
   * Each user's request can be accepted, in which case the user receives the proper amount of Lex tokens,
   * or cancelled, in which case the user gets their underlying back.
   * @dev This function is opened to be called by any EOA or contract.
   * We accrue interest before processing as the pendingDepositAmount changes (causes the virtualBalanceForUtilization to change)
   */
  function processDeposit(
    address[] calldata users
  )
    external
    nonReentrant
    returns (
      uint256 amountDeposited,
      uint256 amountCanceled,
      uint256 counterDeposited,
      uint256 counterCanceled
    )
  {
    poolAccountant.accrueInterest(virtualBalanceForUtilization());

    uint256 epochToProcess = currentEpoch;
    uint256 rate = currentExchangeRate;

    for (uint8 index = 0; index < users.length; index++) {
      (bool existed, bool deposited, uint256 amount) = processDepositSingle(
        epochToProcess,
        users[index],
        rate
      );
      if (!existed) {
        continue;
      }
      if (deposited) {
        amountDeposited += amount;
        counterDeposited += 1;
      } else {
        amountCanceled += amount;
        counterCanceled += 1;
      }
    }
    pendingDepositAmount -= amountDeposited + amountCanceled;
  }

  /**
   * Handles the logic for a single deposit request
   */
  function processDepositSingle(
    uint256 epoch,
    address user,
    uint256 exchangeRate
  ) internal returns (bool existed, bool deposited, uint256 amount) {
    PendingDeposit memory pendingDeposit = pendingDeposits[epoch][user];

    if (0 == pendingDeposit.amount) {
      return (false, false, 0);
    }
    existed = true;
    delete pendingDeposits[epoch][user];

    uint256 actualAmountOut = underlyingAmountToOwnAmountInternal(
      exchangeRate,
      pendingDeposit.amount
    );

    if (actualAmountOut >= pendingDeposit.minAmountOut) {
      _mint(user, actualAmountOut);
      deposited = true;
    } else {
      // Cancelling
      underlying.safeTransfer(user, pendingDeposit.amount);
      deposited = false;
    }
    amount = pendingDeposit.amount;

    emit ProcessedDeposit(user, deposited, amount);
  }

  /**
   * Allows the cancellation of deposit requests whose matching epoch has passed.
   * @dev This function is opened to be called by any EOA or contract.
   * We don't accrue interest here becuase the virtualBalanceForUtilization doesn't change
   * as the underlying balance and the pendingDepositAmount changes cancel each other out.
   */
  function cancelDeposits(
    address[] calldata users,
    uint256[] calldata epochs
  ) external nonReentrant {
    require(users.length == epochs.length, "!ArrayLengths");

    uint256 maxEpochToCancel = currentEpoch - 1;
    for (uint8 index = 0; index < users.length; index++) {
      address user = users[index];
      uint256 epoch = epochs[index];
      require(epoch <= maxEpochToCancel, "Epoch too soon");

      PendingDeposit memory pendingDeposit = pendingDeposits[epoch][user];
      delete pendingDeposits[epoch][user];

      pendingDepositAmount -= pendingDeposit.amount;
      underlying.safeTransfer(user, pendingDeposit.amount);

      emit CanceledDeposit(user, epoch, pendingDeposit.amount);
    }
  }

  /**
   * Allows "processing" of pending redeem requests that are due for the current epoch.
   * @dev This function is opened to be called by any EOA or contract.
   * Accrues interest before processing is required because:
   * 1. We might have cancelled redeems which changes the pendingWithdrawalAmount but not the underlying balance
   * 2. The amountRedeemed and the underlyingAllocated for a specific redeem request might not be the same. Which means
   * that we change the underlying balance and the pendigWithdrawalAmount by different amounts - they don't cancel each other.
   */
  function processRedeems(
    address[] calldata users
  )
    external
    nonReentrant
    returns (
      uint256 amountRedeemed,
      uint256 amountCanceled,
      uint256 counterRedeemed,
      uint256 counterCanceled
    )
  {
    poolAccountant.accrueInterest(virtualBalanceForUtilization());

    uint256 epochToProcess = currentEpoch;
    uint256 rate = currentExchangeRate;

    uint256 underlyingFreeAllocatedAmount = 0;

    for (uint8 index = 0; index < users.length; index++) {
      (
        bool existed,
        bool redeemed,
        uint256 amount,
        uint256 underlyingAllocated
      ) = processRedeemSingle(epochToProcess, users[index], rate);
      if (!existed) {
        continue;
      }
      if (redeemed) {
        amountRedeemed += amount;
        counterRedeemed += 1;
      } else {
        amountCanceled += amount;
        counterCanceled += 1;
      }
      underlyingFreeAllocatedAmount += underlyingAllocated;
    }

    pendingWithdrawalAmount -= underlyingFreeAllocatedAmount;
  }

  /**
   * Handles the logic for a single redeem request
   */
  function processRedeemSingle(
    uint256 epoch,
    address user,
    uint256 exchangeRate
  )
    internal
    returns (
      bool existed,
      bool redeemed,
      uint256 amount,
      uint256 underlyingAllocated
    )
  {
    PendingRedeem memory pendingRedeem = pendingRedeems[epoch][user];
    if (0 == pendingRedeem.amount) {
      return (false, false, 0, 0);
    }
    existed = true;
    delete pendingRedeems[epoch][user];

    uint256 currentUnderlyingAmountOut = ownAmountToUnderlyingAmountInternal(
      exchangeRate,
      pendingRedeem.amount
    );
    uint256 finalUnderlyingAmountOut = (pendingRedeem.maxAmountOut <
      currentUnderlyingAmountOut)
      ? pendingRedeem.maxAmountOut
      : currentUnderlyingAmountOut;

    if (finalUnderlyingAmountOut >= pendingRedeem.minAmountOut) {
      _burn(address(this), pendingRedeem.amount);
      underlying.safeTransfer(user, finalUnderlyingAmountOut);
      redeemed = true;
    } else {
      _transfer(address(this), user, pendingRedeem.amount);
      redeemed = false;
    }

    amount = pendingRedeem.amount;
    underlyingAllocated = pendingRedeem.maxAmountOut;

    emit ProcessedRedeem(user, redeemed, amount);
  }

  /**
   * Allows the cancellation of redeem requests whose matching epoch has passed.
   * @dev This function is opened to be called by any EOA or contract.
   * We need to accure interest as we change the pendingWithdrawalAmount.
   */
  function cancelRedeems(
    address[] calldata users,
    uint256[] calldata epochs
  ) external nonReentrant {
    require(users.length == epochs.length, "!ArrayLengths");

    poolAccountant.accrueInterest(virtualBalanceForUtilization());

    uint256 maxEpochToCancel = currentEpoch - 1;
    for (uint8 index = 0; index < users.length; index++) {
      address user = users[index];
      uint256 epoch = epochs[index];
      require(epoch <= maxEpochToCancel, "Epoch too soon");

      PendingRedeem memory pendingRedeem = pendingRedeems[epoch][user];
      delete pendingRedeems[epoch][user];

      pendingWithdrawalAmount -= pendingRedeem.maxAmountOut;
      _transfer(address(this), user, pendingRedeem.amount);

      emit CanceledRedeem(user, epoch, pendingRedeem.amount);
    }
  }

  // ***** PnL Role interaction functions *****

  /**
   * Advances the Pool's epoch while taking into account the unrealized PnL of the opened positions
   * @dev Can be called only by the "PnlRole"
   */
  function nextEpoch(
    int256 totalUnrealizedPricePnL // Underlying scale
  ) external nonReentrant returns (uint256 newExchangeRate) {
    require(msg.sender == pnlRole, "!Auth");
    require(block.timestamp >= nextEpochStartMin, "!Time pass new epoch");

    (uint256 totalInterest, uint256 interestShare, ) = poolAccountant
      .accrueInterest(virtualBalanceForUtilization());

    int256 unrealizedFunding = poolAccountant.unrealizedFunding();

    uint256 newEpochId = currentEpoch + 1;
    uint256 supply = totalSupply;

    uint256 virtualUnderlyingBalance = 0;

    if (0 == supply) {
      //            newExchangeRate = 1e18;
      newExchangeRate = (10 ** underlyingDecimals); // 1.00
    } else {
      // Note : Subtracting all values that does not belong to the LPs
      //        and adding values that do
      virtualUnderlyingBalance = (underlyingBalanceForExchangeRate()
        .toInt256() +
        unrealizedFunding +
        totalInterest.toInt256() -
        interestShare.toInt256() +
        totalUnrealizedPricePnL).toUint256();

      newExchangeRate = (virtualUnderlyingBalance * (SELF_UNIT_SCALE)) / supply;
    }

    currentEpoch = newEpochId;
    currentExchangeRate = newExchangeRate;
    nextEpochStartMin = calcNextEpochStartMin();

    emit NewEpoch(
      newEpochId,
      totalUnrealizedPricePnL,
      newExchangeRate,
      virtualUnderlyingBalance,
      supply
    );
  }

  // ***** TradingFloor interaction functions *****

  /**
   * Sends assets to a winning trader.
   */
  function sendAssetToTrader(
    address to,
    uint256 amount
  ) external onlyTradingFloor {
    underlying.safeTransfer(to, amount);
  }

  // ***** Internal Views *****

  /**
   * Sanity function to ensure that the utilization is valid
   */
  function verifyUtilizationForLPs() internal view {
    require(isUtilizationForLPsValid(), "LP utilization");
  }

  /**
   * Utility function to get a sub array from a given array
   */
  function getArrItems(
    address[] storage arr,
    uint256 indexFrom,
    uint256 count
  ) internal view returns (address[] memory subArr) {
    uint256 itemsLeft = arr.length - indexFrom;
    count = count < itemsLeft ? count : itemsLeft;

    subArr = new address[](count);
    for (uint256 index = 0; index < count; index++) {
      subArr[index] = arr[indexFrom + index];
    }
  }

  /**
   * Converts the underlying amount to the amount of self tokens by the current exchange rate
   */
  function underlyingAmountToOwnAmountInternal(
    uint256 exchangeRate,
    uint256 underlyingAmount
  ) internal pure returns (uint256 ownAmount) {
    ownAmount = (underlyingAmount * SELF_UNIT_SCALE) / exchangeRate;
  }

  /**
   * Converts the (self) LP amount to the equal underlying amount by the current exchange rate
   */
  function ownAmountToUnderlyingAmountInternal(
    uint256 exchangeRate,
    uint256 ownAmount
  ) internal pure returns (uint256 underlyingAmount) {
    underlyingAmount = (ownAmount * exchangeRate) / SELF_UNIT_SCALE;
  }

  // ***** Underlying utils *****

  /**
   * Utility function to safely take underlying tokens (ERC20) from a pre-approved account
   * @dev Will revert if the contract will not get the exact 'amount' value
   */
  function takeUnderlying(address from, uint amount) internal {
    uint balanceBefore = underlying.balanceOf(address(this));
    underlying.safeTransferFrom(from, address(this), amount);
    uint balanceAfter = underlying.balanceOf(address(this));
    require(balanceAfter - balanceBefore == amount, "DID_NOT_RECEIVE_EXACT");
  }

  // ***** Reentrancy Guard *****

  /**
   * @dev Prevents a contract from calling itself, directly or indirectly.
   */
  modifier nonReentrant() {
    _beforeNonReentrant();
    _;
    _afterNonReentrant();
  }

  /**
   * @dev Tries to get the system lock
   */
  function _beforeNonReentrant() private {
    IRegistryV1(registry).lock();
  }

  /**
   * @dev Releases the system lock
   */
  function _afterNonReentrant() private {
    IRegistryV1(registry).freeLock();
  }
}
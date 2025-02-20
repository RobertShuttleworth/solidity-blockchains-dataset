// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.24;

import "./contracts_Lynx_interfaces_LexErrors.sol";
import "./contracts_Lynx_interfaces_LexPoolAdminEnums.sol";
import "./contracts_Lynx_interfaces_IPoolAccountantV1.sol";
import "./openzeppelin_contracts_token_ERC20_IERC20.sol";

interface LexPoolStructs {
  struct PendingDeposit {
    uint256 amount;
    uint256 minAmountOut;
  }

  struct PendingRedeem {
    uint256 amount;
    uint256 minAmountOut;
    uint256 maxAmountOut;
  }
}

interface LexPoolEvents is LexPoolAdminEnums {
  event NewEpoch(
    uint256 epochId,
    int256 reportedUnrealizedPricePnL,
    uint256 exchangeRate,
    uint256 virtualUnderlyingBalance,
    uint256 totalSupply
  );

  event AddressUpdated(LexPoolAddressesEnum indexed enumCode, address a);
  event NumberUpdated(LexPoolNumbersEnum indexed enumCode, uint value);
  event DepositRequest(
    address indexed user,
    uint256 amount,
    uint256 minAmountOut,
    uint256 processingEpoch
  );
  event RedeemRequest(
    address indexed user,
    uint256 amount,
    uint256 minAmountOut,
    uint256 processingEpoch
  );
  event ProcessedDeposit(
    address indexed user,
    bool deposited,
    uint256 depositedAmount
  );
  event ProcessedRedeem(
    address indexed user,
    bool redeemed,
    uint256 withdrawnAmount // Underlying amount
  );
  event CanceledDeposit(
    address indexed user,
    uint256 epoch,
    uint256 cancelledAmount
  );
  event CanceledRedeem(
    address indexed user,
    uint256 epoch,
    uint256 cancelledAmount
  );
  event ImmediateDepositAllowedToggled(bool indexed value);
  event ImmediateDeposit(
    address indexed depositor,
    uint256 depositAmount,
    uint256 mintAmount
  );
  event ReservesWithdrawn(
    address _to, 
    uint256 interestShare, 
    uint256 totalFundingShare);
}

interface ILexPoolFunctionality is
  IERC20,
  LexPoolStructs,
  LexPoolEvents,
  LexErrors
{
  function setPoolAccountant(
    IPoolAccountantFunctionality _poolAccountant
  ) external;

  function setPnlRole(address pnl) external;

  function setMaxExtraWithdrawalAmountF(uint256 maxExtra) external;

  function setEpochsDelayDeposit(uint256 delay) external;

  function setEpochsDelayRedeem(uint256 delay) external;

  function setEpochDuration(uint256 duration) external;

  function setMinDepositAmount(uint256 amount) external;

  function toggleImmediateDepositAllowed() external;

  function reduceReserves(address _to) external;

  function requestDeposit(
    uint256 amount,
    uint256 minAmountOut,
    bytes32 domain,
    bytes32 referralCode
  ) external;

  function requestDepositViaIntent(
    address user,
    uint256 amount,
    uint256 minAmountOut,
    bytes32 domain,
    bytes32 referralCode
  ) external;

  function requestRedeem(uint256 amount, uint256 minAmountOut) external;

  function requestRedeemViaIntent(
    address user,
    uint256 amount,
    uint256 minAmountOut
  ) external;

  function processDeposit(
    address[] memory users
  )
    external
    returns (
      uint256 amountDeposited,
      uint256 amountCancelled,
      uint256 counterDeposited,
      uint256 counterCancelled
    );

  function cancelDeposits(
    address[] memory users,
    uint256[] memory epochs
  ) external;

  function processRedeems(
    address[] memory users
  )
    external
    returns (
      uint256 amountRedeemed,
      uint256 amountCancelled,
      uint256 counterDeposited,
      uint256 counterCancelled
    );

  function cancelRedeems(
    address[] memory users,
    uint256[] memory epochs
  ) external;

  function nextEpoch(
    int256 totalUnrealizedPricePnL
  ) external returns (uint256 newExchangeRate);

  function currentVirtualUtilization() external view returns (uint256);

  function currentVirtualUtilization(
    uint256 totalBorrows,
    uint256 totalReserves,
    int256 unrealizedFunding
  ) external view returns (uint256);

  function virtualBalanceForUtilization() external view returns (uint256);

  function virtualBalanceForUtilization(
    uint256 extraAmount,
    int256 unrealizedFunding
  ) external view returns (uint256);

  function underlyingBalanceForExchangeRate() external view returns (uint256);

  function sendAssetToTrader(address to, uint256 amount) external;

  function isUtilizationForLPsValid() external view returns (bool);
}

interface ILexPoolV1 is ILexPoolFunctionality {
  function name() external view returns (string memory);

  function symbol() external view returns (string memory);

  function SELF_UNIT_SCALE() external view returns (uint);

  function underlyingDecimals() external view returns (uint256);

  function poolAccountant() external view returns (address);

  function underlying() external view returns (IERC20);

  function tradingFloor() external view returns (address);

  function currentEpoch() external view returns (uint256);

  function currentExchangeRate() external view returns (uint256);

  function nextEpochStartMin() external view returns (uint256);

  function epochDuration() external view returns (uint256);

  function minDepositAmount() external view returns (uint256);

  function epochsDelayDeposit() external view returns (uint256);

  function epochsDelayRedeem() external view returns (uint256);

  function immediateDepositAllowed() external view returns (bool);

  function pendingDeposits(
    uint epoch,
    address account
  ) external view returns (PendingDeposit memory);

  function pendingRedeems(
    uint epoch,
    address account
  ) external view returns (PendingRedeem memory);

  function pendingDepositAmount() external view returns (uint256);

  function pendingWithdrawalAmount() external view returns (uint256);
}
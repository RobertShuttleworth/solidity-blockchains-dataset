// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

interface IKonaFinance {
  event LoanCreated(
    uint256 indexed providerID,
    uint256 indexed loanID,
    address indexed creator,
    uint256 amount,
    address borrower,
    uint8 _status
  );

  event LoanApproved(
    uint256 indexed providerID,
    uint256 indexed loanID,
    string lockReference
  );

  event LoanInvested(
    uint256 indexed providerID,
    uint256 indexed loanID,
    address indexed lender
  );

  event LoanCancelled(
    uint256 indexed providerID,
    uint256 indexed loanID,
    address indexed lender,
    uint256 totalReimbursed
  );

  event LoanDeleted(
    uint256 indexed providerID,
    uint256 indexed loanID,
    address indexed lender,
    uint256 totalReimbursed
  );

  event LoanRepaid(
    uint256 indexed providerID,
    uint256 indexed loanID,
    address contractAddreess,
    uint256 amountRepaid,
    uint256 konaFees,
    uint256 amountForLender
  );

  event LoanWithdrawn(
    uint256 indexed providerID,
    uint256 indexed loanID,
    address indexed lender,
    uint256 amount
  );

  event LoanUpdated(uint256 indexed providerID, uint256 indexed loanID);

  event LenderClaimed(
    uint256 indexed providerID,
    uint256 indexed loanID,
    address indexed lender,
    uint256 total
  );

  event FeesAdded(address indexed beneficiary, uint256 total);

  event FeesClaimed(address indexed caller, uint256 total);

  event KonaFeesSet(uint256 konaFees, address indexed konaAddress);

  event RampAddressSet(address indexed rampAddress);

  event BrzTokenSet(address indexed brzTokenAddress);

  event ProviderEnabled(
    uint256 indexed providerID,
    string name,
    bool autoApprove,
    bool autoWithdraw,
    uint256[] feeAmounts,
    address[] feeWallets
  );

  event ProviderCreatorSet(
    uint256 indexed providerID,
    address indexed creator,
    bool enabled
  );

  event ProviderDisabled(uint256 indexed providerID);
  
  event ProviderUpdated(
    uint256 indexed providerID,
    bool autoApprove,
    bool autoWithdraw,
    uint256 maxLoanAmount
  );
  
  event ProviderFeesReplaced(
    uint256 indexed providerID,
    uint256[] feeAmounts,
    address[] feeWallets
  );

  event RampAddressSetForProvider(uint256 indexed providerID, address indexed rampAddress);

  event FeesAddedForRepayment(uint256 indexed providerID, uint256 indexed loanID, address indexed beneficiary, uint256 totalFees, uint256 totalRepaid);

  event FeesBeneficiaryReplaced(address indexed originalBeneficiary, address indexed newBeneficiary, uint256 total);

  event FeesAddedForDisbursement(uint256 indexed providerID, uint256 indexed loanID, address indexed beneficiary, uint256 totalFees, uint256 originalDisbursementAmount);

  event InvestorSet(address indexed investor, bool enabled);

  function invest(
    uint256 _providerID,
    uint256 _loanID,
    address _payToContract
  ) external;

  function bulkInvest(
    uint256[] calldata _providerIDs,
    uint256[] calldata _loanIDs,
    address[] calldata _payToContracts
  ) external;
}
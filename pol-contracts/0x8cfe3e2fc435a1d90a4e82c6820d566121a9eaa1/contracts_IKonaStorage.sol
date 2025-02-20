// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

interface IKonaStorage {
  struct Provider {
    bool valid;
    string name;
    bool autoApprove;
    bool autoWithdraw;
    uint256 maxLoanAmount;
    uint256[] feeAmounts;
    address[] feeWallets;
    mapping(address => bool) creators;
    mapping(uint256 => Loan) loans;
  }

  struct Conditions {
    uint256 maturity;
    uint256 repayments;
    uint256 interestRate;
    uint256 amountPlusInterest;
    uint256 excessCollateral;
  }

  struct Loan {
    bool valid;
    uint256 amount;
    address borrower;
    string hashInfo;
    LoanStatus status;
    address lender;
    uint256 lenderToClaim;
    address payToContract;
    string lockReference;
    uint256 totalRepaid;
    Conditions conditions;
  }

  enum LoanStatus {
    Created,
    Approved,
    Invested,
    Withdrawn,
    Cancelled,
    Complete
  }

  function getLoanBasic(
    uint256 _providerID,
    uint256 _loanID
  ) external view returns (
    bool isValid,
    uint256 amount,
    LoanStatus status,
    uint256 repayments
  );

  function getLoanConditions(
    uint256 _providerID,
    uint256 _loanID
  ) external view returns (
    bool isValid,
    uint256 maturity,
    uint256 repayments,
    uint256 interestRate,
    uint256 amountPlusInterest,
    uint256 excessCollateral
  );

  struct LoanData {
    uint256 providerID;
    uint256 loanID;
    uint256 amount;
    address borrower;
    string hashInfo;
    uint256 maturity;
    uint256 repayments;
    uint256 interestRate;
    uint256 amountPlusInterest;
    uint256 excessCollateral;
  }
}
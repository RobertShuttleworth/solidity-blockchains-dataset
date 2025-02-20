// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import "./openzeppelin_contracts_token_ERC20_IERC20.sol";
import "./contracts_KonaStorage.sol";
import "./contracts_IKonaFinance.sol";
import "./contracts_IStrategy.sol";

/**
 * @title KonaFinance
 * @dev This contract manages loans and investments for the Kona Finance v1 protocol.
 */
contract KonaFinance is KonaStorage, IKonaFinance {
  uint256 private constant _NOT_ENTERED = 0;
  uint256 private constant _ENTERED = 1;

  modifier nonReentrant() {
      require(_status != _ENTERED, "ReentrancyGuard: reentrant call");
      _status = _ENTERED;
      _;
      _status = _NOT_ENTERED;
  }
 
  modifier nonReentrantBulk() {
    require(_bulkStatus != _ENTERED, "ReentrancyGuard: reentrant call");
    _bulkStatus = _ENTERED;
    _;
    _bulkStatus = _NOT_ENTERED;
}
  
  function bulkCreateLoans(
    LoanData[] calldata loansData
  ) external onlyProxy {
    for (uint256 i = 0; i < loansData.length; i++) {
      createLoanInternal(
        loansData[i].providerID,
        loansData[i].loanID,
        loansData[i].amount,
        loansData[i].borrower,
        loansData[i].hashInfo,
        loansData[i].maturity,
        loansData[i].repayments,
        loansData[i].interestRate,
        loansData[i].amountPlusInterest,
        loansData[i].excessCollateral
      );
    }
  }

  function createLoan(
    uint256 _providerID,
    uint256 _loanID,
    uint256 _amount,
    address _borrower,
    string memory _hashInfo,
    uint256 _maturity,
    uint256 _repayments,
    uint256 _interestRate,
    uint256 _amountPlusInterest,
    uint256 _excessCollateral
  ) external onlyProxy {
    createLoanInternal(
      _providerID,
      _loanID,
      _amount,
      _borrower,
      _hashInfo,
      _maturity,
      _repayments,
      _interestRate,
      _amountPlusInterest,
      _excessCollateral
    );
  }

  function createLoanInternal(
    uint256 _providerID,
    uint256 _loanID,
    uint256 _amount,
    address _borrower,
    string memory _hashInfo,
    uint256 _maturity,
    uint256 _repayments,
    uint256 _interestRate,
    uint256 _amountPlusInterest,
    uint256 _excessCollateral
  ) internal {
    validateLoanConditions(_providerID, _loanID, _amount, _borrower, _interestRate, _amountPlusInterest);

    Loan storage loan = providers[_providerID].loans[_loanID];

    loan.valid = true;

    if (providers[_providerID].autoApprove) {
      loan.status = LoanStatus.Approved;
      emit LoanApproved(_providerID, _loanID, "-");
    } else {
      loan.status = LoanStatus.Created;
    }

    loan.amount = _amount;
    loan.borrower = _borrower;
    loan.hashInfo = _hashInfo;
    loan.conditions.maturity = _maturity;
    loan.conditions.repayments = _repayments;
    loan.conditions.interestRate = _interestRate;
    loan.conditions.amountPlusInterest = _amountPlusInterest;
    loan.conditions.excessCollateral = _excessCollateral;

    emit LoanCreated(
      _providerID,
      _loanID,
      msg.sender,
      _amount,
      _borrower,
      uint8(loan.status)
    );
  }

  function validateLoanConditions(
    uint256 _providerID,
    uint256 _loanID,
    uint256 _amount,
    address _borrower,
    uint256 _interestRate,
    uint256 _amountPlusInterest
  ) internal view {
    require(providers[_providerID].valid, "Invalid provider");
    require(providers[_providerID].creators[msg.sender], "Forbidden access");
    require(
      !providers[_providerID].loans[_loanID].valid,
      "Loan ID already created"
    );
    require(
      _amount > 0 && _interestRate > 0 && _amountPlusInterest >= _amount,
      "Invalid conditions"
    );
    require(
      (providerRampAddresses[_providerID] != address(0) && _borrower == providerRampAddresses[_providerID]) ||
        (providerRampAddresses[_providerID] == address(0) && _borrower != address(0)),
      "Invalid borrower address"
    );
    require(
      providers[_providerID].maxLoanAmount == 0 ||
        _amount <= providers[_providerID].maxLoanAmount,
      "Max amount reached"
    );
  }

  function approveLoan(
    uint256 _providerID,
    uint256 _loanID,
    string memory _lockReference
  ) external onlyRole(LOAN_CONFIRM_ROLE) onlyProxy {
    Loan storage loan = providers[_providerID].loans[_loanID];

    require(loan.status == LoanStatus.Created, "Loan already approved");

    loan.status = LoanStatus.Approved;
    loan.lockReference = _lockReference;

    emit LoanApproved(_providerID, _loanID, _lockReference);
  }

  function invest(
    uint256 _providerID,
    uint256 _loanID,
    address _payToContract
  ) public onlyProxy nonReentrant {
    require(providers[_providerID].valid, "Invalid provider");
    require(whitelistedInvestors[msg.sender], "Not authorized investor");

    Loan storage loan = providers[_providerID].loans[_loanID];

    require(loan.valid, "Invalid loan");
    require(loan.status == LoanStatus.Approved, "Loan is not approved yet");

    loan.lender = msg.sender;
    loan.payToContract = _payToContract;

    require(IERC20(brzToken).transferFrom(msg.sender, address(this), loan.amount), "Transfer failed");

    loan.status = LoanStatus.Withdrawn;

    uint256 remainingAmount = _deductDisbursementFees(_providerID, _loanID, loan.amount);

    require(IERC20(brzToken).transfer(loan.borrower, remainingAmount), "Transfer failed");

    emit LoanWithdrawn(_providerID, _loanID, loan.lender, remainingAmount);
    emit LoanInvested(_providerID, _loanID, msg.sender);
  }

  function bulkInvest(
    uint256[] calldata _providerIDs,
    uint256[] calldata _loanIDs,
    address[] calldata _payToContracts
  ) external onlyProxy nonReentrantBulk {
      require(_providerIDs.length == _loanIDs.length && _loanIDs.length == _payToContracts.length, "Arrays must be of equal length");

      for (uint256 i = 0; i < _providerIDs.length; i++) {
          invest(_providerIDs[i], _loanIDs[i], _payToContracts[i]);
      }
  }

  function cancelLoan(uint256 _providerID, uint256 _loanID) public onlyProxy {
    require(providers[_providerID].valid, "Invalid provider");
    require(
      providers[_providerID].creators[msg.sender] ||
        hasRole(LOAN_MANAGER_ROLE, msg.sender),
      "Forbidden access"
    );

    Loan storage loan = providers[_providerID].loans[_loanID];

    require(loan.valid, "Invalid loan");

    uint256 totalReimbursed = 0;

    if (loan.status == LoanStatus.Invested) {
      totalReimbursed = _reimburseLender(
        _providerID,
        _loanID,
        loan.payToContract,
        loan.lender,
        loan.amount
      );
    } else {
      require(loan.status == LoanStatus.Approved, "Invalid status");
    }

    loan.status = LoanStatus.Cancelled;

    emit LoanCancelled(_providerID, _loanID, loan.lender, totalReimbursed);
  }

  function deleteLoan(
    uint256 _providerID,
    uint256 _loanID
  ) external onlyRole(LOAN_MANAGER_ROLE) onlyProxy {
    require(providers[_providerID].valid, "Invalid provider");

    Loan memory loan = providers[_providerID].loans[_loanID];

    require(loan.valid, "Invalid loan");

    uint256 totalReimbursed = 0;

    if (loan.status == LoanStatus.Invested) {
      totalReimbursed = _reimburseLender(
        _providerID,
        _loanID,
        loan.payToContract,
        loan.lender,
        loan.amount
      );
    }

    delete providers[_providerID].loans[_loanID];

    emit LoanDeleted(_providerID, _loanID, loan.lender, totalReimbursed);
  }

  function _reimburseLender(
    uint256 _providerID,
    uint256 _loanID,
    address _payToContract,
    address _lender,
    uint256 _amount
  ) internal onlyProxy returns (uint256) {
    if (_payToContract == address(0)) {
      IERC20(brzToken).transfer(_lender, _amount);
    } else {
      IStrategy(_payToContract).cancelStrategy(_providerID, _loanID);
    }

    return _amount;
  }

  function _deductDisbursementFees(uint256 _providerID, uint256 _loanID, uint256 _amount) internal onlyProxy returns(uint256) {
    uint256 lenderTotal = _amount;
    for (uint i = 0; i < providers[_providerID].feeAmounts.length; i++) {
      if (!providerFeeIsOnDisbursement[_providerID][i]) {
        continue;
      }
      uint256 totalFees = (_amount * providers[_providerID].feeAmounts[i]) / 1e4;
      address beneficiary = providers[_providerID].feeWallets[i];
      transferFees(totalFees, beneficiary);
      lenderTotal -= totalFees;

      emit FeesAddedForDisbursement(_providerID, _loanID, beneficiary, totalFees, _amount);
    }

    return lenderTotal;
  }

  //Extra collateral is paid back off-chain before calling repay
  function repay(
    uint256 _amount,
    uint256 _providerID,
    uint256 _loanID
  ) external onlyProxy nonReentrant {
    require(providers[_providerID].valid, "Invalid provider");

    require(
      IERC20(brzToken).transferFrom(msg.sender, address(this), _amount),
      "Transfer failed"
    );

    Loan memory loan = providers[_providerID].loans[_loanID];

    require(loan.valid, "Invalid loan");
    require(loan.status == LoanStatus.Withdrawn, "Invalid status");

    uint256 lenderTotal = _amount;

    uint256 konaTotalFees = 0;

    if (konaFees > 0) {
      konaTotalFees += (lenderTotal * konaFees) / 1e4;
      transferFees(konaTotalFees, konaAddress);
      lenderTotal -= konaTotalFees;

      emit FeesAddedForRepayment(_providerID, _loanID, konaAddress, konaTotalFees,  _amount);
    }

    for (uint i = 0; i < providers[_providerID].feeAmounts.length; i++) {
      if (providerFeeIsOnDisbursement[_providerID][i]) {
        continue;
      }
      uint256 totalFees = (_amount * providers[_providerID].feeAmounts[i]) / 1e4;
      address beneficiary = providers[_providerID].feeWallets[i];
      transferFees(totalFees, beneficiary);
      lenderTotal -= totalFees;

      emit FeesAddedForRepayment(_providerID, _loanID, beneficiary, totalFees, _amount);
    }

    if (loan.payToContract == address(0)) {
      require(IERC20(brzToken).transfer(loan.lender, lenderTotal), "Lender transfer failed");
      emit LenderClaimed(_providerID, _loanID, loan.lender, lenderTotal);
    } else {
      IERC20(brzToken).approve(loan.payToContract, lenderTotal);
      IStrategy(loan.payToContract).strategyRepay(
        lenderTotal,
        _providerID,
        _loanID
      );
    }

    providers[_providerID].loans[_loanID].totalRepaid += lenderTotal;

    emit LoanRepaid(
      _providerID,
      _loanID,
      loan.payToContract,
      _amount,
      konaTotalFees,
      lenderTotal
    );
  }

  function transferFees(uint256 _totalFees, address _beneficiary) internal {
    require(IERC20(brzToken).transfer(_beneficiary, _totalFees), "Fee transfer failed");
    emit FeesClaimed(_beneficiary, _totalFees);
  }

  function enableProvider(
    uint256 _providerID,
    string calldata _name,
    uint256[] calldata _feeAmounts,
    address[] calldata _feeWallets,
    bool[] calldata _feeIsOnDisbursement
  ) external onlyRole(PROVIDER_MANAGER_ROLE) onlyProxy {
    require(!providers[_providerID].valid, "Already enabled");
    require(
      _feeAmounts.length == _feeWallets.length,
      "Fee lengths do not match"
    );

    Provider storage provider = providers[_providerID];
    provider.valid = true;
    provider.name = _name;
    provider.autoApprove = true;
    provider.autoWithdraw = true;

    for (uint i = 0; i < _feeAmounts.length; i++) {
      provider.feeAmounts.push(_feeAmounts[i]);
      provider.feeWallets.push(_feeWallets[i]);
    }

    providerFeeIsOnDisbursement[_providerID] = _feeIsOnDisbursement;

    providers[_providerID].creators[msg.sender] = true;

    emit ProviderEnabled(
      _providerID,
      _name,
      true,
      true,
      _feeAmounts,
      _feeWallets
    );
  }

  function updateProvider(
    string memory _name,
    uint256 _providerID,
    bool _autoApprove,
    bool _autoWithdraw,
    uint256 _maxLoanAmount
  ) external onlyRole(PROVIDER_MANAGER_ROLE) onlyProxy {
    require(providers[_providerID].valid, "Invalid provider");

    Provider storage provider = providers[_providerID];
    provider.name = _name;
    provider.autoApprove = _autoApprove;
    provider.autoWithdraw = _autoWithdraw;
    provider.maxLoanAmount = _maxLoanAmount;

    emit ProviderUpdated(_providerID, _autoApprove, _autoWithdraw, _maxLoanAmount);
  }

  function replaceProviderFees(
    uint256 _providerID,
    uint256[] calldata _feeAmounts,
    address[] calldata _feeWallets,
    bool[] calldata _feeIsOnDisbursement
  ) external onlyRole(PROVIDER_MANAGER_ROLE) onlyProxy {
    require(providers[_providerID].valid, "Invalid provider");
    require(
      _feeAmounts.length == _feeWallets.length && _feeAmounts.length == _feeIsOnDisbursement.length,
      "Fee lengths do not match"
    );

    delete providers[_providerID].feeAmounts;
    delete providers[_providerID].feeWallets;
    delete providerFeeIsOnDisbursement[_providerID];

    for (uint i = 0; i < _feeAmounts.length; i++) {
      providers[_providerID].feeAmounts.push(_feeAmounts[i]);
      providers[_providerID].feeWallets.push(_feeWallets[i]);
    }

    providerFeeIsOnDisbursement[_providerID] = _feeIsOnDisbursement;

    emit ProviderFeesReplaced(_providerID, _feeAmounts, _feeWallets);
  }

  function setProviderCreator(
    uint256 _providerID,
    address _creator,
    bool _enabled
  ) external onlyRole(PROVIDER_MANAGER_ROLE) onlyProxy {
    require(providers[_providerID].valid, "Invalid provider");

    providers[_providerID].creators[_creator] = _enabled;

    emit ProviderCreatorSet(_providerID, _creator, _enabled);
  }

  function disableProvider(
    uint256 _providerID
  ) external onlyRole(PROVIDER_MANAGER_ROLE) onlyProxy {
    require(providers[_providerID].valid, "Invalid provider");

    delete providers[_providerID];

    emit ProviderDisabled(_providerID);
  }

  function setInvestor(
      address _investor,
      bool _enabled
  ) external onlyRole(PROVIDER_MANAGER_ROLE) onlyProxy {
      whitelistedInvestors[_investor] = _enabled;
      emit InvestorSet(_investor, _enabled);
  }

  function bulkSetInvestors(
      address[] calldata _investors,
      bool[] calldata _enabled
  ) external onlyRole(PROVIDER_MANAGER_ROLE) onlyProxy {
      require(_investors.length == _enabled.length, "Length mismatch");
      
      for(uint i = 0; i < _investors.length; i++) {
          whitelistedInvestors[_investors[i]] = _enabled[i];
          emit InvestorSet(_investors[i], _enabled[i]);
      }
  }

  function updateLoanState(
    uint256 _providerID,
    uint256 _loanID,
    address _lender,
    address _payToContract,
    LoanStatus _status
  ) external onlyRole(LOAN_MANAGER_ROLE) onlyProxy {
    providers[_providerID].loans[_loanID].lender = _lender;
    providers[_providerID].loans[_loanID].payToContract = _payToContract;
    providers[_providerID].loans[_loanID].status = _status;

    emit LoanUpdated(_providerID, _loanID);
  }

  function bulkUpdateLoanState(
    uint256 _providerID,
    uint256[] calldata _loanIDs,
    LoanStatus _status
  ) external onlyRole(LOAN_MANAGER_ROLE) onlyProxy {
    for (uint256 i = 0; i < _loanIDs.length; i++) {
      providers[_providerID].loans[_loanIDs[i]].status = _status;
      emit LoanUpdated(_providerID, _loanIDs[i]);
    }
  }

  function updateLoanInfo(
    uint256 _providerID,
    uint256 _loanID,
    uint256 _amount,
    address _borrower,
    string memory _hashInfo,
    uint256 _maturity,
    uint256 _repayments,
    uint256 _interestRate,
    uint256 _amountPlusInterest,
    uint256 _excessCollateral
  ) external onlyProxy {
    require(providers[_providerID].valid, "Invalid provider");

    Loan storage loan = providers[_providerID].loans[_loanID];

    require(loan.valid, "Invalid loan");

    if (!hasRole(LOAN_MANAGER_ROLE, msg.sender)) {
      require(providers[_providerID].creators[msg.sender], "Forbidden access");
      require(loan.status == LoanStatus.Created, "Invalid status");
    }

    require(
      _amount > 0 && _interestRate > 0 && _amountPlusInterest >= _amount,
      "Invalid conditions"
    );
    require(
      (providerRampAddresses[_providerID] != address(0) && _borrower == providerRampAddresses[_providerID]) ||
        (providerRampAddresses[_providerID] == address(0) && _borrower != address(0)),
      "Invalid borrower address"
    );
    require(
      providers[_providerID].maxLoanAmount == 0 ||
        _amount <= providers[_providerID].maxLoanAmount,
      "Max amount reached"
    );

    loan.amount = _amount;
    loan.borrower = _borrower;
    loan.hashInfo = _hashInfo;
    loan.conditions.maturity = _maturity;
    loan.conditions.repayments = _repayments;
    loan.conditions.interestRate = _interestRate;
    loan.conditions.amountPlusInterest = _amountPlusInterest;
    loan.conditions.excessCollateral = _excessCollateral;

    emit LoanUpdated(_providerID, _loanID);
  }

  function setKonaFees(
    uint256 _konaFees,
    address _konaAddress
  ) external onlyRole(DEFAULT_ADMIN_ROLE) onlyProxy {
    konaFees = _konaFees;
    konaAddress = _konaAddress;

    emit KonaFeesSet(_konaFees, _konaAddress);
  }

  function setProviderRampAddress(
    uint256 _providerID,
    address _rampAddress
  ) external onlyRole(DEFAULT_ADMIN_ROLE) onlyProxy {
    providerRampAddresses[_providerID] = _rampAddress;

    emit RampAddressSetForProvider(_providerID, _rampAddress);
  }

  /**
   * @dev Function to recover any ERC20 tokens sent accidentally to the contract.
   * Note: Only callable by the super admin and possibly include a time lock.
   */
  function recoverTokens(
    uint256 _amount,
    address _asset
  ) external onlyRole(DEFAULT_ADMIN_ROLE) onlyProxy {
    require(IERC20(_asset).transfer(msg.sender, _amount), "Transfer failed");
  }

  /**
   * @dev Function to recover any ETH sent accidentally to the contract.
   * Note: Only callable by the super admin and possibly include a time lock.
   */
  function recoverETH(uint256 _amount) external onlyRole(DEFAULT_ADMIN_ROLE) onlyProxy {
    payable(msg.sender).transfer(_amount);
  }
}
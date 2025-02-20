// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import "./openzeppelin_contracts-upgradeable_access_AccessControlUpgradeable.sol";
import "./openzeppelin_contracts-upgradeable_proxy_utils_Initializable.sol";
import "./openzeppelin_contracts-upgradeable_proxy_utils_UUPSUpgradeable.sol";
import "./contracts_IKonaStorage.sol";

contract KonaStorage is Initializable, AccessControlUpgradeable, UUPSUpgradeable, IKonaStorage {
  bytes32 public constant LOAN_CONFIRM_ROLE = keccak256("LOAN_CONFIRM_ROLE");
  bytes32 public constant PROVIDER_MANAGER_ROLE = keccak256("PROVIDER_MANAGER_ROLE");
  bytes32 public constant LOAN_MANAGER_ROLE = keccak256("LOAN_MANAGER_ROLE");
  bytes32 public constant UPGRADER_ROLE = keccak256("UPGRADER_ROLE");

  // UPGRADEABILITY FUNCTIONS

  /// @custom:oz-upgrades-unsafe-allow constructor
  constructor() {
      _disableInitializers();
  }

  function initialize(address _brzToken) public initializer {
    __AccessControl_init();
    __UUPSUpgradeable_init();

    konaAddress = msg.sender;
    brzToken = _brzToken;
    konaFees = 0;

    _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
    _grantRole(LOAN_CONFIRM_ROLE, msg.sender);
    _grantRole(PROVIDER_MANAGER_ROLE, msg.sender);
    _grantRole(LOAN_MANAGER_ROLE, msg.sender);
    _grantRole(UPGRADER_ROLE, msg.sender);
  }

  /**
   * @dev Internal function to authorize upgrading the contract to a new implementation.
   *      This is a security feature of UUPS upgradeable contracts and is called by the proxy during an upgrade.
   *      It should contain checks to ensure that only authorized personnel can upgrade the contract.
   *      In this case, it's restricted to the contract owner only.
   * @param newImplementation Address of the new contract implementation to which the proxy will be upgraded.
   */
  function _authorizeUpgrade(address newImplementation) internal onlyRole(UPGRADER_ROLE) override {}

  mapping(uint256 => Provider) public providers;
  mapping(address => uint256) public feesToCollect; // Deprecated, keeping for storage layout compatibility

  uint256 public konaFees;
  address public brzToken;
  address public konaAddress;
  address public rampAddress; // Deprecating this variable but keeping it for storage layout compatibility
  mapping(uint256 => address) public providerRampAddresses; // New mapping for ramp address per provider

  mapping(uint256 => bool[]) public providerFeeIsOnDisbursement; // New mapping for fee type per provider

  mapping(address => bool) public whitelistedInvestors; // Global investor whitelist

  uint256 internal _status;
  uint256 internal _bulkStatus;

  function getProviderFees(
    uint256 _providerID
  )
    external
    view
    returns (uint256[] memory feeAmounts, address[] memory feeWallets)
  {
    if (providers[_providerID].valid) {
      feeAmounts = providers[_providerID].feeAmounts;
      feeWallets = providers[_providerID].feeWallets;
    }
  }

  function getLoan(
    uint256 _providerID,
    uint256 _loanID
  )
    external
    view
    returns (
      bool isValid,
      uint256 amount,
      address borrower,
      LoanStatus status,
      address lender,
      uint256 lenderToClaim,
      address payToContract,
      string memory lockReference,
      uint256 totalRepaid,
      string memory hashInfo
    )
  {
    Loan memory loan = providers[_providerID].loans[_loanID];

    if (!providers[_providerID].valid || !loan.valid) {
      return (
        false,
        0,
        address(0),
        LoanStatus.Created,
        address(0),
        0,
        address(0),
        "",
        0,
        ""
      );
    }

    return (
      true,
      loan.amount,
      loan.borrower,
      loan.status,
      loan.lender,
      loan.lenderToClaim,
      loan.payToContract,
      loan.lockReference,
      loan.totalRepaid,
      loan.hashInfo
    );
  }

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
  ) {
    Loan memory loan = providers[_providerID].loans[_loanID];

    if (!providers[_providerID].valid || !loan.valid) {
      return (false, 0, 0, 0, 0, 0);
    }

    return (
      true,
      loan.conditions.maturity,
      loan.conditions.repayments,
      loan.conditions.interestRate,
      loan.conditions.amountPlusInterest,
      loan.conditions.excessCollateral
    );
  }

  function getLoanBasic(
    uint256 _providerID,
    uint256 _loanID
  ) external view returns (
    bool isValid,
    uint256 amount,
    LoanStatus status,
    uint256 repayments
  ) {
    Loan memory loan = providers[_providerID].loans[_loanID];

    if (!providers[_providerID].valid || !loan.valid) {
      return (false, 0, LoanStatus.Created, 0);
    }

    return (true, loan.amount, loan.status, loan.conditions.repayments);
  }
}
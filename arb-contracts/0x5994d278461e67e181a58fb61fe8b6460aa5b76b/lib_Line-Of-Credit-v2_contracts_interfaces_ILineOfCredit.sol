// SPDX-License-Identifier: GPL-3.0
// Copyright: https://github.com/credit-cooperative/Line-Of-Credit-v2/blob/master/COPYRIGHT.md

pragma solidity ^0.8.25;

import {LineLib} from "./lib_Line-Of-Credit-v2_contracts_utils_LineLib.sol";
import {ICreditPositionToken} from "./lib_Line-Of-Credit-v2_contracts_interfaces_ICreditPositionToken.sol";
import {IInterestRateCredit} from "./lib_Line-Of-Credit-v2_contracts_interfaces_IInterestRateCredit.sol";

interface ILineOfCredit is IInterestRateCredit {
    // Constructor Params
    struct LineParams {
        address lineFactory;
        address tokenContract;
        address oracle;
        address admin;
        address borrower;
        bool recoveryEnabled;
        Fees fees;
    }

    // Lender data
    struct Credit {
        //  all denominated in token, not USD
        uint256 deposit; // The total liquidity provided by a Lender in a given token on a Line of Credit
        uint256 principal; // The amount of a Lender's Deposit on a Line of Credit that has actually been drawn down by the Borrower (in Tokens)
        uint256 interestAccrued; // Interest due by a Borrower but not yet repaid to the Line of Credit contract
        uint256 interestRepaid; // Interest repaid by a Borrower to the Line of Credit contract but not yet withdrawn by a Lender
        uint8 decimals; // Decimals of Credit Token for calcs
        address token; // The token being lent out (Credit Token)
        uint256 tokenId; // The person to repay
        bool isOpen; // Status of position
        bool isRestricted; // Whether the position can be traded
        uint16 earlyWithdrawalFee; // early withdrawal fee paid by lender in BPS
        uint256 deadline; // The timestamp at which the position will be liquidatable
    }

    // in BPS 4 decimals  fee = 50 loan amount = 10000 * (50/100)
    struct Fees {
        uint16 originationFee;
        uint16 swapFee;
        uint16 servicingFee;
    }

    enum FeeTypes {
        ORIGINATION,
        SWAP,
        SERVICING
    }

    // General Events
    event UpdateStatus(uint256 indexed status); // store as normal uint so it can be indexed in subgraph

    event DeployLine(
        address indexed lineFactory, address indexed oracle, address admin, address borrower, bool isRecoverable
    );

    event UpdateBorrower(address indexed borrower, address indexed newBorrower);
    event UpdateAdmin(address indexed oldAdmin, address indexed newAdmin);
    event UpdateServicer(address indexed oldServicer, address indexed newServicer);

    event SortedIntoQ(uint256 indexed id, uint256 indexed newIdx, uint256 indexed oldIdx, uint256 oldId);

    // MutualConsent borrower/lender events

    event AddCredit(uint256 indexed tokenId, uint256 indexed deposit);

    event SetRates(uint256 indexed id, uint128 indexed dRate, uint128 indexed fRate);

    event IncreaseCredit(uint256 indexed id, uint256 indexed deposit);

    event RefinanceCredit(uint256 indexed id, uint256 indexed amount, uint128 dRate, uint128 fRate, uint256 deadline);

    event SetDeadline(uint256 indexed id, uint256 indexed deadline);

    event SetFee(uint16 feeBps, FeeTypes indexed feeType);

    event TransferOriginationFee(uint256 indexed fee, address indexed to);

    event EarlyWithdrawalFee(uint256 indexed fee, address indexed lender, address indexed to);

    // Lender Events

    // Emits data re Lender removes funds (principal) - there is no corresponding function, just withdraw()
    event WithdrawDeposit(uint256 indexed id, uint256 indexed amount);

    // Emits data re Lender withdraws interest - there is no corresponding function, just withdraw()
    event WithdrawProfit(uint256 indexed id, uint256 indexed amount);

    // Emitted when any credit line is closed by the line's borrower or the position's lender
    event CloseCreditPosition(uint256 indexed id);

    // After accrueInterest runs, emits the amount of interest added to a Borrower's outstanding balance of interest due
    // but not yet repaid to the Line of Credit contract
    event InterestAccrued(uint256 indexed id, uint256 indexed amount);

    // Borrower Events

    // receive full line or drawdown on credit
    event Borrow(uint256 indexed id, uint256 indexed amount, address indexed to);

    // Emits that a Borrower has repaid an amount of interest Results in an increase in interestRepaid, i.e. interest not yet withdrawn by a Lender). There is no corresponding function
    event RepayInterest(uint256 indexed id, uint256 indexed amount);

    // Emits that a Borrower has repaid an amount of principal - there is no corresponding function
    event RepayPrincipal(uint256 indexed id, uint256 indexed amount);

    // Emits that a Borrower has paid servicing fee to protocol treasury
    event PayServicingFee(uint256 indexed id, uint256 indexed amount);

    event Default(uint256 indexed id);

    event ServicerApproved(address indexed servicer, bool indexed approved);

    // Access Errors
    error NotActive();
    error NotBorrowing();
    error CallerAccessDenied();

    // Callback Errors
    error LenderIsNotCreditStrategy();

    // Tokens
    error NoTokenPrice();

    // Line
    error BadModule(address module);
    error NoLiquidity();
    error PositionExists();
    error CloseFailedWithPrincipal();
    error NotInsolvent(address module);
    error NotLiquidatable();
    error AlreadyInitialized();
    error PositionIsClosed();
    error RepayAmountExceedsDebt(uint256 totalAvailable);
    error CantStepQ();
    error EthSupportDisabled();
    error BorrowFailed();
    error RecoveryNotEnabled();
    error MaximumFeeExceeded();
    error InvalidAddress();

    error NoQueue();
    error NonceMismatch();
    error BadStatus();
    error InvalidDeadline();
    error EthNotSupported();

    // Fully public functions

    function init() external;

    // MutualConsent functions

    function setFees(Fees memory _fees) external;

    function addCredit(
        uint256 desiredNonce,
        uint128 drate,
        uint128 frate,
        uint256 amount,
        address token,
        address lender,
        bool isRestricted,
        uint16 earlyWithdrawalFee,
        uint256 deadline
    ) external returns (uint256);

    function refinanceCredit(
        uint256 desiredNonce,
        uint256 tokenId,
        uint256 amount,
        uint128 drate,
        uint128 frate,
        uint256 deadline
    ) external;

    // Borrower functions
    function updateBorrower(address newBorrower) external;
    function borrow(uint256 id, uint256 amount, address to) external;
    function depositAndRepay(uint256 amount) external;
    function depositAndClose() external;
    function close(uint256 id) external;
    function claimEarlyWithdrawalFees(uint256 tokenId) external;

    // Lender functions
    function withdraw(uint256 tokenId, uint256 amount) external;

    // Admin functions
    function updateAdmin(address newAdmin) external;
    function setServicer(address servicer, bool approved) external;

    // Recovery functions
    function recoverTokens(address token, address to) external;

    // State management functions
    function declareInsolvent() external;
    function accrueInterest() external;
    function healthcheck() external returns (LineLib.STATUS);
    function stepQ() external;
    function updateOutstandingDebt() external returns (uint256, uint256);

    // State getters
    function status() external view returns (LineLib.STATUS);
    function borrower() external view returns (address);
    function admin() external view returns (address);
    function isServicer(address) external view returns (bool);
    function protocolTreasury() external view returns (address);
    function counts() external view returns (uint256, uint256);
    function getCreditPosition(uint256 tokenId) external view returns (Credit memory);
    function nextInQ() external view returns (uint256, uint256, address, uint256, uint256, uint256, uint128, uint128);
    function available(uint256 id) external view returns (uint256, uint256);
    function tokenContract() external view returns (ICreditPositionToken);
    function interestAccrued(uint256 id) external view returns (uint256);
    function getFees() external view returns (Fees memory);
    function ids(uint256 idx) external returns (uint256);
    function recoveryEnabled() external view returns (bool);
    function nonce() external view returns (uint256);
    function getLineFactory() external view returns (address);
}
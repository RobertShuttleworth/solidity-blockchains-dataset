// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.19;

import "./openzeppelin_contracts-upgradeable_proxy_utils_Initializable.sol";
import "./openzeppelin_contracts-upgradeable_proxy_utils_UUPSUpgradeable.sol";
import "./openzeppelin_contracts-upgradeable_security_PausableUpgradeable.sol";
import "./openzeppelin_contracts-upgradeable_security_ReentrancyGuardUpgradeable.sol";
import "./openzeppelin_contracts-upgradeable_access_OwnableUpgradeable.sol";
import "./openzeppelin_contracts-upgradeable_token_ERC20_IERC20Upgradeable.sol";
import "./openzeppelin_contracts-upgradeable_token_ERC721_IERC721Upgradeable.sol";
import "./openzeppelin_contracts-upgradeable_token_ERC721_IERC721ReceiverUpgradeable.sol";
import "./openzeppelin_contracts-upgradeable_utils_AddressUpgradeable.sol";
import "./openzeppelin_contracts-upgradeable_utils_cryptography_draft-EIP712Upgradeable.sol";
import "./openzeppelin_contracts-upgradeable_utils_cryptography_ECDSAUpgradeable.sol";
import "./contracts_library_LibLoan.sol";
import "./contracts_interface_IBlockUnblockAccess.sol";
import "./openzeppelin_contracts-upgradeable_token_ERC20_extensions_IERC20MetadataUpgradeable.sol";

/**
 * @title NFTLoan
 * @dev A contract for lending nfts and transferring loan amounts to borrowers.
 */
contract NFTLoanV2 is
    Initializable,
    UUPSUpgradeable,
    EIP712Upgradeable,
    OwnableUpgradeable,
    PausableUpgradeable,
    ReentrancyGuardUpgradeable,
    IERC721ReceiverUpgradeable
{

    bytes4 constant public NEW_LOAN_CLASS = bytes4(keccak256("NEW"));
    bytes4 constant public COMPLETED_LOAN_CLASS = bytes4(keccak256("COMPLETED"));
    bytes4 constant public CANCELLED_LOAN_CLASS = bytes4(keccak256("CANCELLED"));
    bytes4 constant public CLOSED_LOAN_CLASS = bytes4(keccak256("CLOSED"));
    bytes4 constant public REPAYED_LOAN_CLASS = bytes4(keccak256("REPAYED"));

    uint256 constant secondsInDay = 86400;
    mapping(uint256 => bytes4) public loanStatus;
    mapping(uint256 => LibLoan.Loan) public loans;
    mapping(uint256 => LibLoan.LoanRequest) public loanRequests;
    mapping(uint256 => address) public previousOwner;
    IBlockUnblockAccess public blockAccessContract;
    string public constant name = "Lending Borrowing";

    address public platformFeeAddress;
    uint256 public borrowerLoanAcceptFeePercentage;
    uint256 public lenderLoanAcceptFeePercentage;
    uint256 public borrowerLoanRepayFeePercentage;
    uint256 public lenderLoanRepayFeePercentage;
    uint256 public BorrowerLoanRepaySpreadFeePercentage;
    uint256 public LenderLoanRepaySpreadFeePercentage;
    uint256 public BorrowerSpreadTimelineDays;
    uint256 public LenderSpreadTimelineDays;
    uint256 public borrowerLoanAcceptFeeFixedAmount;
    uint256 public lenderLoanAcceptFeeFixedAmount;
    uint256 public borrowerLoanRepayFeeFixedAmount;
    uint256 public lenderLoanRepayFeeFixedAmount;
    uint256 public BorrowerLoanRepaySpreadFeeFixedAmount;
    uint256 public LenderLoanRepaySpreadFeeFixedAmount;

    event LoanCreated(LibLoan.Loan loan);
    event LoanCancelled(uint256 loanId);
    event LoanClosed(uint256 loanId);
    event LoanAccepted(LibLoan.LoanRequest loan, address walletAddress);
    event LoanRepaid(uint256 loanId, uint256 repaymentWithInterest);
    event LoanEdited(LibLoan.Loan loan);
    event LoanRequestAccepted(LibLoan.LoanRequest loan, address walletAddress);
    event FeeSettingsUpdated(
        address indexed platformFeeAddress,
        uint256 borrowerLoanAcceptFee,
        uint256 lenderLoanAcceptFee,
        uint256 borrowerLoanRepayFee,
        uint256 lenderLoanRepayFee,
        uint256 borrowerLoanRepaySpreadFee,
        uint256 lenderLoanRepaySpreadFee,
        uint256 borrowerSpreadTimelineDays,
        uint256 lenderSpreadTimelineDays,
        uint256 borrowerLoanAcceptFeeFixedAmount,
        uint256 lenderLoanAcceptFeeFixedAmount,
        uint256 borrowerLoanRepayFeeFixedAmount,
        uint256 lenderLoanRepayFeeFixedAmount,
        uint256 borrowerLoanRepaySpreadFeeFixedAmount,
        uint256 lenderLoanRepaySpreadFeeFixedAmount
    );

    /**
     * @dev Initializes the contract and sets the initial values.
     */
    function initialize(address _blockAccessContract) external initializer {
        __Ownable_init_unchained();
        __Pausable_init_unchained();
        __ReentrancyGuard_init_unchained();
        __EIP712_init_unchained("Loan", "1");
        blockAccessContract = IBlockUnblockAccess(_blockAccessContract);
    }

    /**
     * @dev Creates a loan.
     *
     * Requirements:
     * @param loan - Object of borrow loan.
     *
     * Emits a {LoanCreated} event, indicating the loan.
     */
    function createLoan(LibLoan.Loan memory loan) external whenNotPaused nonReentrant {
        require(blockAccessContract.blockedUsers(msg.sender) == false, "User blocked");
        require(loan.borrower == msg.sender, "Only borrower can create loan");
        // existing loan validation
        require(loanStatus[loan.loanId] == 0x00000000, "Loan already exists");

        // update loan mapping/status
        setLoanMapping(loan);
        loanStatus[loan.loanId] = NEW_LOAN_CLASS;

        for (uint256 i = 0; i < loan.nfts.length; i++) {
            IERC721Upgradeable token = IERC721Upgradeable(loan.nfts[i].collectionAddress);
            require(token.ownerOf(loan.nfts[i].tokenId) == msg.sender, "Not the owner of the token");
            token.safeTransferFrom(msg.sender, address(this), loan.nfts[i].tokenId);
            previousOwner[loan.loanId] = msg.sender;
        }
        emit LoanCreated(loan);
    }

    /**
     * @dev Edit a loan.
     *
     * Requirements:
     * @param loan - Object of borrow loan.
     *
     * Emits a {LoanCreated} event, indicating the loan.
     */
    function editLoan(LibLoan.Loan memory loan) external whenNotPaused nonReentrant {
        require(blockAccessContract.blockedUsers(msg.sender) == false, "User blocked");
        LibLoan.Loan memory existingLoan = loans[loan.loanId];
        require(existingLoan.borrower == msg.sender, "Only borrower can edit loan");
        _validateloanStatus(loan.loanId);

        // update loan mapping/status
        loans[loan.loanId].duration = loan.duration;
        loans[loan.loanId].loanPaymentContract = loan.loanPaymentContract;
        loans[loan.loanId].loanAmount = loan.loanAmount;
        loans[loan.loanId].loanPercentage = loan.loanPercentage;

        emit LoanEdited(loan);
    }

    /**
     * @dev Cancel a loan.
     *
     * Requirements:
     * @param loanId - loan id.
     *
     * Emits a {LoanCancelled} event, indicating the loan id.
     */
    function cancelLoan(uint256 loanId) external whenNotPaused nonReentrant {
        require(blockAccessContract.blockedUsers(msg.sender) == false, "User blocked");
        LibLoan.Loan memory loan = loans[loanId];
        require(loan.borrower == msg.sender, "Only borrower can cancel loan");
        _validateloanStatus(loan.loanId);

        // update loan status
        loanStatus[loan.loanId] = CANCELLED_LOAN_CLASS;

        for (uint256 i = 0; i < loan.nfts.length; i++) {
            IERC721Upgradeable token = IERC721Upgradeable(loan.nfts[i].collectionAddress);
            require(previousOwner[loan.loanId] == msg.sender, "Not the owner of this request");
            token.safeTransferFrom(address(this), msg.sender, loan.nfts[i].tokenId);
        }
        emit LoanCancelled(loanId);
        previousOwner[loan.loanId] = address(0);
    }

    /**
     * @dev Accept a loan.
     *
     * Requirements:
     * @param loanRequest - Object of loan accept request.
     *
     * Emits a {LoanAccepted} event, indicating the loan accept request.
     */
    function acceptLoan(LibLoan.LoanRequest memory loanRequest) external whenNotPaused nonReentrant {
        require(blockAccessContract.blockedUsers(msg.sender) == false, "User blocked");
        _validateloanStatus(loanRequest.loanId);

        LibLoan.Loan memory loan = loans[loanRequest.loanId];
        require(loanRequest.borrower == loan.borrower, "Invalid borrower");
        require(loanRequest.duration > 0, "Invalid duration");
        require(loanRequest.loanAmount > 0, "Invalid loan amount");
        require(
            loanRequest.loanPaymentContract != address(0),
            "Loan contract not to be zero"
        );

        setLoanReqestMapping(loanRequest);
        loanStatus[loanRequest.loanId] = COMPLETED_LOAN_CLASS;

        IERC20Upgradeable loanPaymentContract = IERC20Upgradeable(loanRequest.loanPaymentContract);
        // Calculate the fees 
        uint256 borrowerFee = calculateFeeAmount(loanRequest.loanAmount, borrowerLoanAcceptFeePercentage, IERC20MetadataUpgradeable(loanRequest.loanPaymentContract), borrowerLoanAcceptFeeFixedAmount);
        uint256 lenderFee = calculateFeeAmount(loanRequest.loanAmount, lenderLoanAcceptFeePercentage, IERC20MetadataUpgradeable(loanRequest.loanPaymentContract), lenderLoanAcceptFeeFixedAmount);
        // Transfer the loan amount to the borrower
        if((lenderFee + borrowerFee) > 0){
            loanPaymentContract.transferFrom(loanRequest.lender, platformFeeAddress, lenderFee + borrowerFee);
        }
        loanPaymentContract.transferFrom(loanRequest.lender, loanRequest.borrower, loanRequest.loanAmount - borrowerFee);

        emit LoanAccepted(loanRequest, msg.sender);
    }

    /**
     * @dev Accept counter offer of a loan.
     *
     * Requirements:
     * @param loanRequest - Object of counter offer accept request.
     * @param signature - to verify lender.
     *
     * Emits a {LoanAccepted} event, indicating the loan accept request.
     */
    function acceptCounterOffer(LibLoan.LoanRequest memory loanRequest, bytes calldata signature) external whenNotPaused nonReentrant {
        require(blockAccessContract.blockedUsers(msg.sender) == false, "User blocked");
        _validateloanStatus(loanRequest.loanId);

        LibLoan.Loan memory loan = loans[loanRequest.loanId];
        require(loanRequest.borrower == loan.borrower, "Invalid borrower");
        require(loanRequest.duration > 0, "Invalid duration");
        require(loanRequest.loanAmount > 0, "Invalid loan amount");
        require(
            loanRequest.loanPaymentContract != address(0),
            "Loan contract not to be zero address"
        );

        // verify signature
        bytes32 structHash = LibLoan._genLoanRequestHash(loanRequest);
        bytes32 hashTypedData = _hashTypedDataV4(structHash);
        address lender = verifySignature(hashTypedData, signature);
        require(lender == loanRequest.lender, "Loan: Signature Incorrect");

        loanRequest.startTime = block.timestamp;
        setLoanReqestMapping(loanRequest);
        loanStatus[loanRequest.loanId] = COMPLETED_LOAN_CLASS;

        IERC20Upgradeable loanPaymentContract = IERC20Upgradeable(loanRequest.loanPaymentContract);
        // calculate fees
        uint256 borrowerFee = calculateFeeAmount(loanRequest.loanAmount, borrowerLoanAcceptFeePercentage, IERC20MetadataUpgradeable(loanRequest.loanPaymentContract), borrowerLoanAcceptFeeFixedAmount);
        uint256 lenderFee = calculateFeeAmount(loanRequest.loanAmount, lenderLoanAcceptFeePercentage, IERC20MetadataUpgradeable(loanRequest.loanPaymentContract), lenderLoanAcceptFeeFixedAmount);
        // Transfer the loan amount to the borrower
        if((lenderFee + borrowerFee) > 0){
            loanPaymentContract.transferFrom(loanRequest.lender, platformFeeAddress, lenderFee + borrowerFee);
        }
        loanPaymentContract.transferFrom(loanRequest.lender, loanRequest.borrower, loanRequest.loanAmount - borrowerFee);

        emit LoanAccepted(loanRequest, msg.sender);
    }

    /**
     * @dev Repay a loan.
     *
     * Requirements:
     * @param loanId - loan id.
     *
     * Emits a {LoanRepaid} event, indicating the loan id and repayment amount.
     */
    function repayLoan(uint256 loanId) external whenNotPaused nonReentrant {
        require(blockAccessContract.blockedUsers(msg.sender) == false, "User blocked");
        LibLoan.LoanRequest storage loan = loanRequests[loanId];
        // require(getDurationInDays(loanId) > 0, "Repay after one day");

        require(loan.borrower == msg.sender, "Only borrower can repay the loan");
        require(block.timestamp < loan.startTime + (loan.duration * secondsInDay), "Loan duration exceeds");
        
        uint256 durationInDays = getDurationInDays(loanId);

        uint256 repaymentWithInterest = calculateRepaymentWithInterest(loanId, durationInDays);

        IERC20Upgradeable loanPaymentContract = IERC20Upgradeable(loan.loanPaymentContract);
        uint256 borrowerFee = calculateFeeAmount(loan.loanAmount, borrowerLoanRepayFeePercentage, IERC20MetadataUpgradeable(loan.loanPaymentContract), borrowerLoanRepayFeeFixedAmount);
        uint256 lenderFee = calculateFeeAmount(loan.loanAmount, lenderLoanRepayFeePercentage, IERC20MetadataUpgradeable(loan.loanPaymentContract), lenderLoanRepayFeeFixedAmount);
        uint256 borrowerSpreadFee = calculateSpreadFee(loanId, BorrowerLoanRepaySpreadFeePercentage, BorrowerSpreadTimelineDays, IERC20MetadataUpgradeable(loan.loanPaymentContract), BorrowerLoanRepaySpreadFeeFixedAmount);
        uint256 lenderSpreadFee = calculateSpreadFee(loanId, LenderLoanRepaySpreadFeePercentage, LenderSpreadTimelineDays, IERC20MetadataUpgradeable(loan.loanPaymentContract), LenderLoanRepaySpreadFeeFixedAmount);
        if((lenderFee + borrowerFee + borrowerSpreadFee + lenderSpreadFee)>0){
            loanPaymentContract.transferFrom(msg.sender, platformFeeAddress, lenderFee + borrowerFee + borrowerSpreadFee + lenderSpreadFee);
        }
        loanPaymentContract.transferFrom(msg.sender, loan.lender, repaymentWithInterest - (lenderFee + lenderSpreadFee));

        for (uint256 i = 0; i < loan.nfts.length; i++) {
            IERC721Upgradeable token = IERC721Upgradeable(
                loan.nfts[i].collectionAddress
            );
            token.safeTransferFrom(address(this), loan.borrower, loan.nfts[i].tokenId);
        }

        loanStatus[loan.loanId] = REPAYED_LOAN_CLASS;

        emit LoanRepaid(loanId, repaymentWithInterest);
    }

    /**
     * @dev Force close a loan.
     *
     * Requirements:
     * @param loanId - loan id.
     *
     * Emits a {LoanClosed} event, indicating the loan id.
     */
    function forceClose(uint256 loanId) external whenNotPaused nonReentrant {
        require(blockAccessContract.blockedUsers(msg.sender) == false, "User blocked");
        LibLoan.LoanRequest storage loan = loanRequests[loanId];

        require(loan.lender == msg.sender, "Only lender can force close the loan");
        require(
            block.timestamp > loan.startTime + (loan.duration * secondsInDay),
            "Loan duration not yet completed"
        );

        for (uint256 i = 0; i < loan.nfts.length; i++) {
            IERC721Upgradeable token = IERC721Upgradeable(
                loan.nfts[i].collectionAddress
            );
            token.safeTransferFrom(address(this), loan.lender, loan.nfts[i].tokenId);
        }

        loanStatus[loan.loanId] = CLOSED_LOAN_CLASS;

        emit LoanClosed(loanId);
    }

    /**
     * @dev Pause the contract (stopped state) by owner.
     *
     * Requirements:
     * - The contract must not be paused.
     * 
     * Emits a {Paused} event.
     */
    function pause() external onlyOwner {
        _pause();
    }

    /**
     * @dev Unpause the contract (normal state) by owner.
     *
     * Requirements:
     * - The contract must be paused.
     * 
     * Emits a {Unpaused} event.
     */
    function unpause() external onlyOwner whenPaused {
        _unpause();
    }

    /**
     * @dev Internal function to calculate repayment with interest that are calculated in advance at start of the day.
     * @param loanId - loan id.
     * @param loanDurationInDays - duration in days.
     * @return uint256 - repayment amount with interest.
     */
    function calculateRepaymentWithInterest(uint256 loanId, uint256 loanDurationInDays) public view returns (uint256) {
        LibLoan.LoanRequest memory loan = loanRequests[loanId];
        uint256 interestRatePerDay = loan.loanPercentage * 1e18 / 36500;
        uint256 interestAmount = loan.loanAmount * interestRatePerDay * (loanDurationInDays+1) / 1e18;
        uint256 repaymentWithInterest = interestAmount + loan.loanAmount;
        return repaymentWithInterest;
    }

    /**
     * @dev Internal function to get duration in days.
     * @param loanId - loan id.
     * @return uint256 - duration in days.
     */
    function getDurationInDays(uint256 loanId) public view returns (uint256) {
        LibLoan.LoanRequest memory loan = loanRequests[loanId];
        uint256 secondsTraveled = block.timestamp - loan.startTime;
        uint256 daysTraveled = secondsTraveled / 1 days;
        return daysTraveled;
    }

    /**
     * @dev Internal function to validate loan status.
     * @param loanId - loan id.
     */
    function _validateloanStatus(uint256 loanId) view internal {
        require(loanStatus[loanId] == NEW_LOAN_CLASS, "Loan is not created yet");
        require(loanStatus[loanId] != COMPLETED_LOAN_CLASS, "Loan is already completed");
        require(loanStatus[loanId] != CANCELLED_LOAN_CLASS, "Loan is already cancelled");
        require(loanStatus[loanId] != CLOSED_LOAN_CLASS, "Loan is already closed");
        require(loanStatus[loanId] != REPAYED_LOAN_CLASS, "Loan is already repayed");
    }

    /**
     * @dev Internal function to verify the signature.
     * @param hash - bytes of signature params.
     * @param signature.
     * @return address - signer address
     */
    function verifySignature(bytes32 hash, bytes calldata signature) internal pure returns (address) {
        return ECDSAUpgradeable.recover(hash, signature);
    }

    /**
     * @dev Internal function to set loan mapping.
     * @param loan - loan object.
     */
    function setLoanMapping(LibLoan.Loan memory loan) internal {
        for (uint256 i = 0; i < loan.nfts.length; i++) {
            loans[loan.loanId].nfts.push(loan.nfts[i]);
        }  
        loans[loan.loanId].borrower = loan.borrower;
        loans[loan.loanId].duration = loan.duration;
        loans[loan.loanId].loanPaymentContract = loan.loanPaymentContract;
        loans[loan.loanId].loanAmount = loan.loanAmount;
        loans[loan.loanId].loanPercentage = loan.loanPercentage;
        loans[loan.loanId].loanId = loan.loanId;
    }

    /**
     * @dev Internal function to set loan request mapping.
     * @param loanRequest - loan request object.
     */
    function setLoanReqestMapping(LibLoan.LoanRequest memory loanRequest) internal {
        for (uint256 i = 0; i < loanRequest.nfts.length; i++) {
            loanRequests[loanRequest.loanId].nfts.push(loanRequest.nfts[i]);
        }  
        loanRequests[loanRequest.loanId].borrower = loanRequest.borrower;
        loanRequests[loanRequest.loanId].lender = loanRequest.lender;
        loanRequests[loanRequest.loanId].requestId = loanRequest.requestId;
        loanRequests[loanRequest.loanId].startTime = loanRequest.startTime;
        loanRequests[loanRequest.loanId].duration = loanRequest.duration;
        loanRequests[loanRequest.loanId].loanPaymentContract = loanRequest.loanPaymentContract;
        loanRequests[loanRequest.loanId].loanAmount = loanRequest.loanAmount;
        loanRequests[loanRequest.loanId].loanPercentage = loanRequest.loanPercentage;
        loanRequests[loanRequest.loanId].loanId = loanRequest.loanId;
    }

    function onERC721Received(address operator, address from, uint256 tokenId, bytes calldata data) external override returns (bytes4) {
        return this.onERC721Received.selector;
    }

    function _authorizeUpgrade(
        address newImplementation
    ) internal override onlyOwner {}

    function acceptLoanOffer(LibLoan.LoanRequest memory loanRequest, bytes calldata signature) external whenNotPaused nonReentrant {
        require(blockAccessContract.blockedUsers(msg.sender) == false, "User blocked");
        require(loanRequest.borrower == msg.sender, "Only borrower can accept open loan request");
        require(loanRequest.duration > 0, "Invalid duration");
        require(loanRequest.loanAmount > 0, "Invalid loan amount");
        require(
            loanRequest.loanPaymentContract != address(0),
            "Loan contract not to be zero address"
        );
        // existing loan validation
        require(loanStatus[loanRequest.loanId] == 0x00000000, "Loan already exists");

        // verify signature
        bytes32 structHash = LibLoan._genLoanOfferHash(loanRequest);
        bytes32 hashTypedData = _hashTypedDataV4(structHash);
        address lender = verifySignature(hashTypedData, signature);
        require(lender == loanRequest.lender, "Loan: Signature Incorrect");
        loanRequest.startTime = block.timestamp;

        // update loan mapping/status
        setLoanReqestMapping(loanRequest);
        loanStatus[loanRequest.loanId] = COMPLETED_LOAN_CLASS;

        for (uint256 i = 0; i < loanRequest.nfts.length; i++) {
            IERC721Upgradeable token = IERC721Upgradeable(loanRequest.nfts[i].collectionAddress);
            require(token.ownerOf(loanRequest.nfts[i].tokenId) == msg.sender, "Not the owner of the token");
            token.safeTransferFrom(msg.sender, address(this), loanRequest.nfts[i].tokenId);
            previousOwner[loanRequest.loanId] = msg.sender;
        }
        
        IERC20Upgradeable loanPaymentContract = IERC20Upgradeable(loanRequest.loanPaymentContract);

        loanPaymentContract.transferFrom(loanRequest.lender, loanRequest.borrower, loanRequest.loanAmount);

        emit LoanRequestAccepted(loanRequest, msg.sender);
    }

    /**
     * @notice Sets various fee percentages and timelines for the contract.
     * @dev This function can only be called by the owner of the contract.
     * @param _platformFeeAddress The address to set as the platform fee address.
     * @param _borrowerLoanAcceptFeePercentage The new fee percentage to be set for the borrower when accepting a loan.
     * @param _lenderLoanAcceptFeePercentage The new fee percentage to be set for the lender when accepting a loan.
     * @param _borrowerLoanRepayFeePercentage The new fee percentage to be set for the borrower when repaying a loan.
     * @param _lenderLoanRepayFeePercentage The new fee percentage to be set for the lender when repaying a loan.
     * @param _borrowerLoanRepaySpreadFeePercentage The new spread fee percentage to be set for the borrower when repaying a loan.
     * @param _lenderLoanRepaySpreadFeePercentage The new spread fee percentage to be set for the lender when repaying a loan.
     * @param _borrowerSpreadTimelineDays The new timeline in days for the borrower to pay the spread fee.
     * @param _lenderSpreadTimelineDays The new timeline in days for the lender to pay the spread fee.
     * @param _borrowerLoanAcceptFeeFixedAmount The new fixed fee amount to be set for the borrower when accepting a loan.
     * @param _lenderLoanAcceptFeeFixedAmount The new fixed fee amount to be set for the lender when accepting a loan.
     * @param _borrowerLoanRepayFeeFixedAmount The new fixed fee amount to be set for the borrower when repaying a loan.
     * @param _lenderLoanRepayFeeFixedAmount The new fixed fee amount to be set for the lender when repaying a loan.
     * @param _borrowerLoanRepaySpreadFeeFixedAmount The new fixed spread fee amount to be set for the borrower when repaying a loan.
     * @param _lenderLoanRepaySpreadFeeFixedAmount The new fixed spread fee amount to be set for the lender when repaying a loan.
     */
    function updateFeeSetting(
        address _platformFeeAddress,
        uint256 _borrowerLoanAcceptFeePercentage,
        uint256 _lenderLoanAcceptFeePercentage,
        uint256 _borrowerLoanRepayFeePercentage,
        uint256 _lenderLoanRepayFeePercentage,
        uint256 _borrowerLoanRepaySpreadFeePercentage,
        uint256 _lenderLoanRepaySpreadFeePercentage,
        uint256 _borrowerSpreadTimelineDays,
        uint256 _lenderSpreadTimelineDays,
        uint256 _borrowerLoanAcceptFeeFixedAmount,
        uint256 _lenderLoanAcceptFeeFixedAmount,
        uint256 _borrowerLoanRepayFeeFixedAmount,
        uint256 _lenderLoanRepayFeeFixedAmount,
        uint256 _borrowerLoanRepaySpreadFeeFixedAmount,
        uint256 _lenderLoanRepaySpreadFeeFixedAmount
    ) external onlyOwner {
        require(_platformFeeAddress != address(0), "Address cannot be zero address");
        require(
            _borrowerLoanAcceptFeePercentage <= 10_000 &&
            _lenderLoanAcceptFeePercentage <= 10_000 &&
            _borrowerLoanRepayFeePercentage <= 10_000 &&
            _lenderLoanRepayFeePercentage <= 10_000 &&
            _borrowerLoanRepaySpreadFeePercentage <= 10_000 &&
            _lenderLoanRepaySpreadFeePercentage <= 10_000 &&
            _borrowerSpreadTimelineDays > 0 &&
            _lenderSpreadTimelineDays > 0,
            "Invalid fee setting"
        );

        platformFeeAddress = _platformFeeAddress;
        borrowerLoanAcceptFeePercentage = _borrowerLoanAcceptFeePercentage;
        lenderLoanAcceptFeePercentage = _lenderLoanAcceptFeePercentage;
        borrowerLoanRepayFeePercentage = _borrowerLoanRepayFeePercentage;
        lenderLoanRepayFeePercentage = _lenderLoanRepayFeePercentage;
        BorrowerLoanRepaySpreadFeePercentage = _borrowerLoanRepaySpreadFeePercentage;
        LenderLoanRepaySpreadFeePercentage = _lenderLoanRepaySpreadFeePercentage;
        BorrowerSpreadTimelineDays = _borrowerSpreadTimelineDays;
        LenderSpreadTimelineDays = _lenderSpreadTimelineDays;
        borrowerLoanAcceptFeeFixedAmount = _borrowerLoanAcceptFeeFixedAmount;
        lenderLoanAcceptFeeFixedAmount = _lenderLoanAcceptFeeFixedAmount;
        borrowerLoanRepayFeeFixedAmount = _borrowerLoanRepayFeeFixedAmount;
        lenderLoanRepayFeeFixedAmount = _lenderLoanRepayFeeFixedAmount;
        BorrowerLoanRepaySpreadFeeFixedAmount = _borrowerLoanRepaySpreadFeeFixedAmount;
        LenderLoanRepaySpreadFeeFixedAmount = _lenderLoanRepaySpreadFeeFixedAmount;

        emit FeeSettingsUpdated(
            _platformFeeAddress,
            _borrowerLoanAcceptFeePercentage,
            _lenderLoanAcceptFeePercentage,
            _borrowerLoanRepayFeePercentage,
            _lenderLoanRepayFeePercentage,
            _borrowerLoanRepaySpreadFeePercentage,
            _lenderLoanRepaySpreadFeePercentage,
            _borrowerSpreadTimelineDays,
            _lenderSpreadTimelineDays,
            _borrowerLoanAcceptFeeFixedAmount,
            _lenderLoanAcceptFeeFixedAmount,
            _borrowerLoanRepayFeeFixedAmount,
            _lenderLoanRepayFeeFixedAmount,
            _borrowerLoanRepaySpreadFeeFixedAmount,
            _lenderLoanRepaySpreadFeeFixedAmount
        );
    }

    /**
     * @dev Calculates the spread fee based on the loan amount and a given fee percentage.
     * @param loanId - The ID of the loan for which to calculate the spread fee.
     * @param _fee - The fee percentage to be applied to the loan amount, based on basis point.
     * @param _days - The timeline in days for the borrower to pay the spread fee.
     * @return uint256 - The calculated spread fee.
     */
    function calculateSpreadFee(uint256 loanId, uint256 _fee, uint256 _days, IERC20MetadataUpgradeable _currencyAddress, uint256 _fixedAmount) internal view returns (uint256) {
        LibLoan.LoanRequest memory loan = loanRequests[loanId];
        uint256 durationInDays = getDurationInDays(loanId);
        uint256 spreadFee = calculateFeeAmount(loan.loanAmount, _fee, _currencyAddress, _fixedAmount);
        uint256 numberSpreadFeeTermPassed = durationInDays / _days;
        return spreadFee * numberSpreadFeeTermPassed;
    }

    /**
     * @dev Calculates the borrower fee based on the loan amount and a given fee percentage.
     * @param _amount - The amount of the loan.
     * @param _feePercentage - The fee percentage to be applied to the loan amount, based on basis point.
     * @return uint256 - The calculated fee.
     */
    function calculateFeeAmount(uint256 _amount, uint256 _feePercentage, IERC20MetadataUpgradeable _currencyAddress, uint256 _fixedAmount) internal view returns (uint256) {
        uint256 fixedFeeAmount = calculateEquivalentTokenAmount(_currencyAddress, _fixedAmount);
        uint256 percentageFeeAmount = (_amount * _feePercentage) / 10_000;
        return fixedFeeAmount + percentageFeeAmount;
    }

    /**
     * @dev Calculates the equivalent token amount in smallest units based on the token's decimals.
     * @param _token The ERC20 token for which the equivalent amount is calculated.
     * @param _amount The amount of tokens in standard units.
     * @return The equivalent amount in smallest units.
     */
    function calculateEquivalentTokenAmount(
        IERC20MetadataUpgradeable _token,
        uint256 _amount
    ) internal view returns (uint256) {
        uint8 decimals = _token.decimals();
        return _amount * (10 ** decimals);
    }

    /**
     * @notice Retrieves the NFTs associated with a specific loan.
     * @param loanId The ID of the loan for which to retrieve the NFTs.
     * @return An array of NFTs associated with the specified loan.
     */
    function getLoanNFTs(uint256 loanId) public view returns (LibLoan.NFT[] memory) {
    return loans[loanId].nfts;
}
}
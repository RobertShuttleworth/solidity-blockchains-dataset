// SPDX-License-Identifier: GPL-3.0
// Copyright: https://github.com/credit-cooperative/Line-Of-Credit-v2/blob/master/COPYRIGHT.md

import {IERC20} from "./lib_openzeppelin-contracts_contracts_token_ERC20_IERC20.sol";
import {SafeERC20} from "./lib_openzeppelin-contracts_contracts_token_ERC20_utils_SafeERC20.sol";
import {LineLib} from "./lib_Line-Of-Credit-v2_contracts_utils_LineLib.sol";
import {CreditLib} from "./lib_Line-Of-Credit-v2_contracts_utils_CreditLib.sol";
import {CreditListLib} from "./lib_Line-Of-Credit-v2_contracts_utils_CreditListLib.sol";
import {FeesLib} from "./lib_Line-Of-Credit-v2_contracts_utils_FeesLib.sol";
import {MutualConsent} from "./lib_Line-Of-Credit-v2_contracts_utils_MutualConsent.sol";
import {InterestRateCredit} from "./lib_Line-Of-Credit-v2_contracts_modules_interest-rate_InterestRateCredit.sol";
import {ICreditPositionToken} from "./lib_Line-Of-Credit-v2_contracts_interfaces_ICreditPositionToken.sol";
import {IOracle} from "./lib_Line-Of-Credit-v2_contracts_interfaces_IOracle.sol";
import {ILineOfCredit} from "./lib_Line-Of-Credit-v2_contracts_interfaces_ILineOfCredit.sol";
import {IEscrowedLine} from "./lib_Line-Of-Credit-v2_contracts_interfaces_IEscrowedLine.sol";
import {IEscrow} from "./lib_Line-Of-Credit-v2_contracts_interfaces_IEscrow.sol";
import {ILineFactory} from "./lib_Line-Of-Credit-v2_contracts_interfaces_ILineFactory.sol";
import {ICreditStrategyLike} from "./lib_Line-Of-Credit-v2_contracts_interfaces_ICreditStrategyLike.sol";
import {Denominations} from "./lib_chainlink_contracts_src_v0.8_Denominations.sol";
import {ReentrancyGuard} from "./lib_openzeppelin-contracts_contracts_utils_ReentrancyGuard.sol";
import "./lib_Line-Of-Credit-v2_contracts_utils_SafeCallMinGas.sol";

/**
 * @title  - Credit Cooperative Unsecured Line of Credit
 * @author - Credit Cooperative
 * @notice - Core credit facility logic for proposing, depositing, borrowing, and repaying debt.
 *         - Contains core financial covnenants around term length (`deadline`), collateral ratios, liquidations, etc.
 * @dev    - contains internal functions overwritten by SecuredLine, SpigotedLine, and EscrowedLine
 */
abstract contract LineOfCredit is ILineOfCredit, InterestRateCredit, MutualConsent, ReentrancyGuard {
    using SafeERC20 for IERC20;

    using CreditListLib for uint256[];

    /// @notice - the account that can drawdown and manage debt positions
    address public borrower;

    /// @notice - the contract that manages the ERC-721 credit position tokens
    ICreditPositionToken public tokenContract;

    /// @notice - neutral 3rd party that mediates btw borrower and all lenders
    address public admin;

    /// @notice - addresses delegated by the admin to handle servicing
    mapping(address => bool) public isServicer;

    /// @notice - boolean to enable or disable recovery functionality
    bool public recoveryEnabled;

    /// @notice - factory that deploys Credit Coop Line of Credits
    ILineFactory internal immutable lineFactory;

    /// @notice - price feed to use for valuing credit tokens
    IOracle internal immutable oracle;

    /// @notice - current number of active positions (aka non-null ids) in `ids` list
    uint256 internal count;

    /// @notice - positions ids of all open credit lines.
    /// @dev    - may contain null elements
    uint256[] public ids;

    // in BPS 4 decimals  fee = 50 loan amount = 10000 * (50/100)
    Fees internal fees;

    /// @notice id -> position data
    mapping(uint256 => Credit) internal credits;

    /// @notice - mapping of position id to early withdrawal fee
    mapping(uint256 => uint256) public claimableEarlyWithdrawalFees;

    /// @notice - current health status of line
    LineLib.STATUS public status;

    /// @notice - the nonce of the line of credit used to protect lenders from borrowers changing terms
    uint256 public nonce = 0;

    /**
     * @notice            - How to deploy a Line of Credit
     * @dev               - A Borrower and a first Lender agree on terms. Then the Borrower deploys the contract using the constructor below.
     *                      Later, both Lender and Borrower must call _mutualConsent() during addCredit() to actually enable funds to be deposited.
     * @param oracle_     - The price oracle to use for getting all token values.
     */
    constructor(address oracle_) {
        oracle = IOracle(oracle_);
    }

    /**
     * @notice  - Runs logic to ensure Line owns all modules are configured properly - collateral, interest rates, admin, etc.
     *          - Changes `status` from UNINITIALIZED to ACTIVE
     * @dev     - Reverts on failure to update status
     */
    function init() external virtual {
        if (status != LineLib.STATUS.UNINITIALIZED) {
            revert AlreadyInitialized();
        }
        _init();
        _updateStatus(LineLib.STATUS.ACTIVE);
    }

    function _init() internal virtual {
        // If no collateral or Spigot then Line of Credit is immediately active
        return;
    }

    /**
     * @notice - Allows the admin and borrower to mutually agree to set the fees for the line of credit
     * @param _fees - The fees to set for the line of credit
     * @dev - only the admin or borrower can call this function
     */
    function setFees(Fees memory _fees) external mutualConsent(admin, _endBorrower()) {
        _assertMaxFee(_fees.originationFee, FeeTypes.ORIGINATION);
        _assertMaxFee(_fees.swapFee, FeeTypes.SWAP);
        _assertMaxFee(_fees.servicingFee, FeeTypes.SERVICING);
        fees = _fees;
    }

    /**
     * @notice             - Asserts that the fee is less than the maximum allowed.
     * @param fee          - The fee to assert.
     */
    function _assertMaxFee(uint16 fee, FeeTypes fee_type) internal {
        if (fee > BASE_DENOMINATOR) {
            revert MaximumFeeExceeded();
        }
        emit SetFee(fee, fee_type);
    }

    ///////////////
    // MODIFIERS //
    ///////////////

    function _unauthorized() private pure {
        revert CallerAccessDenied();
    }

    function _whileActive() private view {
        if (status != LineLib.STATUS.ACTIVE) {
            revert NotActive();
        }
    }

    function _whileActiveOrRepaid() private view {
        if (status != LineLib.STATUS.ACTIVE && status != LineLib.STATUS.REPAID) {
            revert NotActive();
        }
    }

    function _whileBorrowing() internal view {
        if (count == 0 || credits[ids[0]].principal == 0) {
            revert NotBorrowing();
        }
    }

    function _onlyBorrower() internal view {
        if (msg.sender != borrower) {
            _unauthorized();
        }
    }

    function _onlyBorrowerOrServicer() internal view {
        if (msg.sender != borrower && !isServicer[msg.sender]) {
            _unauthorized();
        }
    }

    function _onlyAdmin() internal view {
        if (msg.sender != admin) {
            _unauthorized();
        }
    }

    function _isRecoverable() internal view {
        if (!recoveryEnabled) {
            revert RecoveryNotEnabled();
        }
    }

    function _onlyTokenHolder(uint256 tokenId) internal view {
        if (tokenId != 0 && tokenContract.ownerOf(tokenId) != msg.sender) {
            _unauthorized();
        }
    }

    function _onlyTokenHolderOrBorrower(uint256 tokenId) internal view {
        if (tokenId != 0 && tokenContract.ownerOf(tokenId) != msg.sender && msg.sender != borrower) {
            _unauthorized();
        }
    }

    function _mutualConsentById(uint256 tokenId) private returns (bool) {
        return _mutualConsent(borrower, tokenContract.ownerOf(tokenId));
    }

    /**
     * @notice - returns address that can call borrow() function
     *  @dev - if borrower is escrow, return escrow address otherwise return line borrower address
     */
    function _endBorrower() internal view returns (address) {
        address escrowBorrower = IEscrow(IEscrowedLine(address(this)).escrow()).borrower();
        return escrowBorrower;
    }

    /**
     * @notice - mutualConsent() but hardcodes borrower address and uses the position id to
     *              get Lender address instead of passing it in directly
     * @param tokenId - the id of the token that owns the position
     */
    modifier mutualConsentById(uint256 tokenId) {
        if (_mutualConsentById(tokenId)) {
            _;
        } else {
            if (msg.sender == tokenContract.ownerOf(tokenId)) {
                tokenContract.openProposal(tokenId);
            }
        }
    }

    /**
     * @notice - Allows borrower to update their address.
     * @notice - Updates both line.borrower and escrow.borrower
     * @dev    - only callable by `borrower`
     * @dev    - cannot be called if new borrower is zero address
     * @dev    - clears all credit proposals
     * @param newBorrower The new address of the borrower
     */
    function updateBorrower(address newBorrower) external {
        _onlyBorrower();
        if (newBorrower == address(0)) {
            revert InvalidAddress();
        }

        // update line.borrower if EscrowType == ESCROW (i.e. line.borrower is escrow.borrower)
        if (borrower == _endBorrower()) {
            emit UpdateBorrower(borrower, newBorrower);
            borrower = newBorrower;
        }

        // update line state
        nonce++;
        _clearProposals();

        // update escrow.borrower
        IEscrow(IEscrowedLine(address(this)).escrow()).updateBorrower(newBorrower);
    }

    /**
     * @notice - update the admin address
     * @param newAdmin - the new admin address
     * @dev - only the current admin can call this function
     */
    function updateAdmin(address newAdmin) external virtual {
        _onlyAdmin();
        if (newAdmin == address(0)) {
            revert InvalidAddress();
        }
        emit UpdateAdmin(admin, newAdmin);
        setServicer(newAdmin, true);
        admin = newAdmin;
        nonce++;
    }

    /**
     * @notice - update servicer roles
     * @dev    - only callable by `admin`
     * @param servicer - the new servicer address
     * @param approved - whether the servicer is approved or not
     */
    function setServicer(address servicer, bool approved) public {
        _onlyAdmin();
        if (servicer == address(0)) {
            revert InvalidAddress();
        }
        emit ServicerApproved(servicer, approved);
        isServicer[servicer] = approved;
    }

    /**
     * @notice  - evaluates all covenants encoded in _healthcheck from different Line variants
     * @dev     - updates `status` variable in storage if current status is diferent from existing status
     * @return  - current health status of Line
     */
    function healthcheck() external returns (LineLib.STATUS) {
        // can only check if the line has been initialized
        if (uint256(status) >= uint256(LineLib.STATUS.ACTIVE)) {
            return _updateStatus(_healthcheck());
        }
        revert BadStatus();
    }

    function _healthcheck() internal virtual returns (LineLib.STATUS) {
        // if line is in a final end state then do not run _healthcheck()
        LineLib.STATUS s = status;
        if (
            s == LineLib.STATUS.REPAID // end state - good
                || s == LineLib.STATUS.INSOLVENT // end state - bad
                || s == LineLib.STATUS.ABORTED // end state - bad
        ) {
            return s;
        }

        // Liquidate if all credit lines aren't closed by deadline
        // go through all open positions, if any are past deadline then liquidate
        // NOTE we use count because ids.length might contain null elements
        for (uint256 i; i < count; ++i) {
            uint256 id = ids[i];
            Credit memory credit = credits[id];
            if (block.timestamp >= credit.deadline) {
                emit Default(id); // can query all defaulted positions offchain once event picked up
                return LineLib.STATUS.LIQUIDATABLE;
            }
        }
        return s;
    }

    /**
     * @notice - Allow the Admin to signify that the Borrower is incapable of repaying debt permanently.
     *         - Recoverable funds for Lender after declaring insolvency = deposit + interestRepaid - principal
     * @dev    - Needed for onchain impairment accounting e.g. updating ERC4626 share price
     * @dev    - Callable only by Admin.
     */
    function declareInsolvent() external {
        _onlyAdmin();
        if (LineLib.STATUS.LIQUIDATABLE != _updateStatus(_healthcheck())) {
            revert NotLiquidatable();
        }
        _updateStatus(LineLib.STATUS.INSOLVENT);
    }

    /**
     * @notice - Returns the total debt of a Borrower across all positions for all Lenders.
     * @dev    - Denominated in USD, 8 decimals.
     * @dev    - callable by anyone
     * @return totalPrincipal - total amount of principal, in USD, owed across all positions
     * @return totalInterest - total amount of interest, in USD,  owed across all positions
     */
    function updateOutstandingDebt() external returns (uint256, uint256) {
        return _updateOutstandingDebt();
    }

    function _updateOutstandingDebt() internal returns (uint256 principal, uint256 interest) {
        // use full length not count because positions might not be packed in order
        uint256 len = ids.length;
        if (len == 0) return (0, 0);

        uint256 id;
        for (uint256 i; i < len; ++i) {
            id = ids[i];

            // null element in array from closing a position. skip for gas savings
            if (id == 0) {
                continue;
            }
            Credit storage credit = credits[id];
            (uint256 _p, uint256 _i) = CreditLib.getOutstandingDebt(
                credits[id], id, address(oracle), _accrueInterest(id, credit.principal, credit.deposit)
            );

            // update total outstanding debt
            principal += _p;
            interest += _i;
        }
    }

    /**
     *
     * @notice - Updates accrued interest for the whole Line of Credit facility (i.e. for all credit lines)
     * @dev    - Loops over all position ids and calls related internal functions during which InterestRateCredit.sol
     *           is called with the id data and then 'interestAccrued' is updated.
     * @dev    - The related internal function _accrue() is called by other functions any time the balance on an individual
     *           credit line changes or if the interest rates of a credit line are changed by mutual consent
     *           between a Borrower and a Lender.
     */
    function accrueInterest() external {
        uint256 len = ids.length;
        uint256 id;
        for (uint256 i; i < len; ++i) {
            id = ids[i];
            _accrue(credits[id], id);
        }
    }

    /**
     * @notice                   - On first call, creates proposed terms and emits MutualConsentRegistsered event. No position is created.
     *                             - On second call, creates position and stores in Line contract, sets interest rates, and starts accruing facility rate fees.
     * @dev                      - Requires mutualConsent participants send EXACT same params when calling addCredit
     * @dev                      - Fully executes function after a Borrower and a Lender have agreed terms, both Lender and borrower have agreed through mutualConsent
     * @dev                      - callable by `lender` and `borrower`
     * @param drate              - The interest rate charged to a Borrower on borrowed / drawn down funds. In bps, 4 decimals.
     * @param frate              - The interest rate charged to a Borrower on the remaining funds available, but not yet drawn down
     *                     (rate charged on the available headroom). In bps, 4 decimals.
     * @param amount             - The amount of Credit Token to initially deposit by the Lender
     * @param token              - The Credit Token, i.e. the token to be lent out
     * @param lender             - The address that will manage credit line
     * @param isRestricted       - Whether the position can be traded
     * @param earlyWithdrawalFee - fee paid by lender for withdrawing deposit early
     * @param deadline           - The deadline for the position
     * @return tokenId           - Lender's position id to look up in `erc721` to get the posiition id
     */
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
    ) external mutualConsent(lender, borrower) returns (uint256 tokenId) {
        _whileActiveOrRepaid();

        if (desiredNonce != nonce) {
            revert NonceMismatch();
        }

        if (deadline <= block.timestamp) {
            revert InvalidDeadline();
        }

        if (Denominations.ETH == token) {
            revert EthNotSupported();
        }

        if (earlyWithdrawalFee > BASE_DENOMINATOR) {
            revert MaximumFeeExceeded();
        }

        // send lender tokens to line
        LineLib.receiveTokenOrETH(token, lender, amount);

        tokenId = tokenContract.mint(address(lineFactory), lender, address(this), isRestricted);

        // create credit position
        _createCredit(tokenId, token, amount, isRestricted, earlyWithdrawalFee, deadline);

        // determine origination fee
        uint256 proratedOriginationFee = 0;
        if (fees.originationFee != 0) {
            proratedOriginationFee = FeesLib._calculateOriginationFee(fees, amount, deadline);
        }

        _setRates(tokenId, drate, frate);

        if (status == LineLib.STATUS.REPAID) {
            _updateStatus(LineLib.STATUS.ACTIVE);
        }

        if (proratedOriginationFee != 0) {
            address protocolTreasury_ = protocolTreasury();
            // send origination fees to line from borrower
            LineLib.receiveTokenOrETH(token, _endBorrower(), proratedOriginationFee);
            // send origination fees to protocol treasury
            LineLib.sendOutTokenOrETH(token, protocolTreasury_, proratedOriginationFee);
            emit TransferOriginationFee(proratedOriginationFee, protocolTreasury_);
        }

        // If lender is CreditStrategy, update Vault accounting, otherwise do nothing
        // Note: tested extensively in Vaults repo
        _tryAddCreditPosition(lender, tokenId, amount);
    }

    /**
     * @notice           - lets Lender and Borrower update rates on the lender's position
     *                   - accrues interest before updating terms, per InterestRate docs
     *                   - can do so even when LIQUIDATABLE for the purpose of refinancing and/or renego
     * @dev              - callable by Borrower or Lender
     * @param id         - id that we are updating
     * @param drate      - new drawn rate. In bps, 4 decimals
     * @param frate      - new facility rate. In bps, 4 decimals
     */
    function _setRates(uint256 id, uint128 drate, uint128 frate) internal {
        _accrue(credits[id], id);
        _setRate(id, drate, frate);
        emit SetRates(id, drate, frate);
    }

    /**
     * @notice           - Lets a Lender and a Borrower increase the credit limit on a position
     * @dev              - line status must be ACTIVE
     * @dev              - callable by borrower
     * @param tokenId    - position id that we are updating
     * @param amount     - amount to deposit by the Lender
     */
    function _increaseCredit(uint256 tokenId, uint256 amount, uint256 oldDeadline, uint256 newDeadline) internal {
        address lender = tokenContract.ownerOf(tokenId);
        uint256 proratedOriginationFee = 0;

        Credit storage credit = credits[tokenId];
        _accrue(credit, tokenId);

        // add new origination fee for existing deposit
        if (fees.originationFee != 0) {
            // only pay origination fee for the deadline extension, not for current deadline
            uint256 remainingTimeToLive = oldDeadline - block.timestamp;
            proratedOriginationFee = proratedOriginationFee
                + FeesLib._calculateOriginationFee(fees, credits[tokenId].deposit, newDeadline - remainingTimeToLive);
        }

        if (amount > 0) {
            // add new origination fee for new deposit
            if (fees.originationFee != 0) {
                proratedOriginationFee =
                    proratedOriginationFee + FeesLib._calculateOriginationFee(fees, amount, newDeadline);
            }

            credit.deposit += amount;

            // send lender tokens to the line
            LineLib.receiveTokenOrETH(credit.token, lender, amount);

            emit IncreaseCredit(tokenId, amount);

            // If lender is CreditStrategy, update Vault accounting, otherwise do nothing
            // Note: tested extensively in Vaults repo
            _tryAddCreditPosition(lender, tokenId, amount);
        }

        // transfer orgination fees
        if (proratedOriginationFee != 0) {
            address protocolTreasury_ = protocolTreasury();
            // send origination fees to line from borrower
            LineLib.receiveTokenOrETH(credit.token, _endBorrower(), proratedOriginationFee);
            // send origination fees to protocol treasury
            LineLib.sendOutTokenOrETH(credit.token, protocolTreasury_, proratedOriginationFee);
            emit TransferOriginationFee(proratedOriginationFee, protocolTreasury_);
        }
    }

    /**
     * @notice             - Lets a Lender and a Borrower refinance a credit position
     * @dev                - line status must be ACTIVE
     * @dev                - callable by borrower
     * @dev                - The function retains the `payable` designation, despite not accepting Eth via mutualConsent modifier, as a gas-optimization
     * @param desiredNonce - nonce to prevent sandwich attacks
     * @param tokenId      - position id that we are updating
     * @param amount       - amount to deposit by the Lender
     * @param dRate        - new drawn rate. In bps, 4 decimals
     * @param fRate        - new facility rate. In bps, 4 decimals
     * @param deadline     - new deadline for the credit position
     */
    function refinanceCredit(
        uint256 desiredNonce,
        uint256 tokenId,
        uint256 amount,
        uint128 dRate,
        uint128 fRate,
        uint256 deadline
    ) public mutualConsentById(tokenId) {
        _whileActive();
        if (desiredNonce != nonce) {
            revert NonceMismatch();
        }
        if (msg.sender != tokenContract.ownerOf(tokenId)) {
            tokenContract.closeProposal(tokenId);
        }

        if (deadline <= block.timestamp) {
            revert InvalidDeadline();
        }

        // allows dRate and fRate to be 0 for interest free credit positions
        _setRates(tokenId, dRate, fRate);

        // update deadline of credit position
        uint256 oldDeadline = credits[tokenId].deadline;
        credits[tokenId].deadline = deadline;
        emit SetDeadline(tokenId, deadline);

        // increase credit if amount is greater than 0
        _increaseCredit(tokenId, amount, oldDeadline, deadline);

        emit RefinanceCredit(tokenId, amount, dRate, fRate, deadline);
    }

    ///////////////
    // REPAYMENT //
    ///////////////

    /**
     * @notice       - A Borrower deposits enough tokens to repay and close a credit line.
     * @dev          - callable by borrower
     */
    function depositAndClose() external {
        _whileBorrowing();
        _onlyBorrowerOrServicer();

        uint256 id = ids[0];
        Credit storage credit = credits[id];
        _accrue(credit, id);

        // msg.sender deposits the outstanding balance not already repaid
        uint256 totalOwed = credit.principal + credit.interestAccrued;

        // Add servicing fee
        totalOwed += FeesLib._calculateServicingFee(fees, totalOwed);

        // msg.sender clears the debt then closes the credit line
        _repay(credit, id, totalOwed, msg.sender);
        _close(credit, id);
    }

    /**
     * @notice - Removes and deletes a position, preventing any more borrowing or interest.
     *         - Requires that the position principal has already been repaid in full
     * @dev    - MUST repay accrued interest from facility fee during call
     * @dev - callable by `borrower` or `admin`
     * @param id -the position id to be closed
     */
    function close(uint256 id) public virtual {
        _onlyBorrowerOrServicer();
        Credit storage credit = credits[id];
        _accrue(credit, id);
        uint256 totalOwed = credit.interestAccrued + FeesLib._calculateServicingFee(fees, credit.interestAccrued);

        // msg.sender clears facility fees and close position
        _repay(credit, id, totalOwed, msg.sender);
        _close(credit, id);
    }

    /**
     * @notice       - Transfers token used in position id from msg.sender to Line contract.
     * @dev          - Available for anyone to deposit Credit Tokens to be available to be withdrawn by Lenders
     * @notice       - see LineOfCredit._repay() for more details
     * @param amount - amount of `token` in `id` to pay back
     */
    function depositAndRepay(uint256 amount) external {
        _whileBorrowing();
        uint256 id = ids[0];
        Credit storage credit = credits[id];
        _accrue(credit, id);

        uint256 servicingFeeAmount = FeesLib._calculateServicingFeeFromAmount(fees, amount);

        // if amount is greater than total owed, adjust amount to be total owed
        if (amount > credit.principal + credit.interestAccrued + servicingFeeAmount) {
            servicingFeeAmount = FeesLib._calculateServicingFee(fees, credit.principal + credit.interestAccrued);
            amount = credit.principal + credit.interestAccrued + servicingFeeAmount;
        }

        _repay(credit, id, amount, msg.sender);
    }

    ////////////////////
    // FUND TRANSFERS //
    ////////////////////

    /**
     * @notice       - Borrower chooses which lender position draw down on and transfers tokens from Line contract to Borrower
     * @dev          - callable by borrower
     * @param id     - the position to draw down on
     * @param amount - amount of tokens the borrower wants to withdraw
     * @param to - address to send tokens to. defaults to `borrower` if no address provided
     */
    function borrow(uint256 id, uint256 amount, address to) external {
        _whileActive();
        _onlyBorrower();
        Credit storage credit = credits[id];
        _accrue(credit, id);
        if (!credit.isOpen) {
            revert PositionIsClosed();
        }
        if (amount > credit.deposit - credit.principal) {
            revert NoLiquidity();
        }
        credit.principal += amount;

        // ensure that borrowing doesnt cause Line to be LIQUIDATABLE
        LineLib.STATUS status_ = _updateStatus(_healthcheck());

        if (status_ != LineLib.STATUS.ACTIVE) {
            revert BorrowFailed();
        }

        // If the "to" address is not provided (i.e., it's the zero address), set it to the borrower.
        if (to == address(0)) {
            to = borrower;
        }

        _sortIntoQ(id);
        emit Borrow(id, amount, to);

        LineLib.sendOutTokenOrETH(credit.token, to, amount);
    }

    /**
     * @notice - Withdraws liquidity from a Lender's position available to the Borrower.
     *         - Lender is only allowed to withdraw tokens not already lent out
     *         - Withdraws from repaid interest (profit) first and then deposit is reduced
     * @dev - can only withdraw tokens from their own position. If multiple lenders lend DAI, the lender1 can't withdraw using lender2's tokens
     * @dev - callable by Lender on `id`
     * @param tokenId - the position id that Lender is withdrawing from
     * @param amount - amount of tokens the Lender would like to withdraw (withdrawn amount may be lower)
     */
    function withdraw(uint256 tokenId, uint256 amount) external {
        _onlyTokenHolder(tokenId);
        // accrues interest and transfer funds to Lender addres
        uint256 fee = 0;

        // dont penalize if they are only withdrawing interest that has been repaid
        if (status == LineLib.STATUS.ACTIVE) {
            if (block.timestamp < credits[tokenId].deadline && amount > credits[tokenId].interestRepaid) {
                fee = FeesLib._calculateEarlyWithdrawalFee(credits[tokenId].earlyWithdrawalFee, amount);
            }
        }

        // check status, if active, penalize the lender by taking a % of withdrawn amount and sending to borrower.
        // can use the same OG fee equation
        Credit storage credit = credits[tokenId];
        _accrue(credit, tokenId);
        if (fee != 0) {
            claimableEarlyWithdrawalFees[tokenId] += fee;
            emit EarlyWithdrawalFee(fee, msg.sender, borrower);
        }

        CreditLib.withdraw(credit, tokenId, msg.sender, amount, fee);
    }

    /**
     * @notice - Allows the borrower to claim the early withdrawal fee paid by the lender
     * @param tokenId - the id of the position to claim the fee from
     */
    function claimEarlyWithdrawalFees(uint256 tokenId) external {
        _onlyBorrower();
        uint256 amount = claimableEarlyWithdrawalFees[tokenId];
        claimableEarlyWithdrawalFees[tokenId] = 0;
        LineLib.sendOutTokenOrETH(credits[tokenId].token, msg.sender, amount);
    }

    /**
     * @notice - Allows the admin to recover tokens from the Line of Credit
     * @param token - the address of the token to recover
     * @param to - the address to send the recovered tokens to
     */
    function recoverTokens(address token, address to) external {
        _onlyAdmin();
        if (status != LineLib.STATUS.ABORTED) {
            revert BadStatus();
        }
        IERC20(token).safeTransfer(to, IERC20(token).balanceOf(address(this)));
    }

    /**
     * @notice - Cycles through position ids and selects first position with non-null principal to the zero index
     * @dev - Only works if the first element in the queue is null
     */
    function stepQ() external {
        _onlyAdmin();
        ids.stepQ();
    }

    //////////////////////
    //  Internal  funcs //
    //////////////////////

    /**
     * @notice - Checks if target address supports the interface
     * @param target - the address of the lender
     * @param interfaceId - the interface id to check
     * @return - true if the target address supports the interface, otherwise false
     */
    function _safeSupportsInterface(address target, bytes4 interfaceId) internal view returns (bool) {
        // First check if address has code
        if (target.code.length == 0) return false;

        // Low-level call to supportsInterface
        (bool success, bytes memory data) = target.staticcall(
            abi.encodeWithSelector(0x01ffc9a7, interfaceId) // 0x01ffc9a7 is bytes4(keccak256("supportsInterface(bytes4)"))
        );

        // Check if call was successful and returned exactly 32 bytes
        if (!success || data.length != 32) return false;

        // Decode the return value
        return abi.decode(data, (bool));
    }

    /**
     * @notice - Updates Vault accounting if lender is a CreditStrategy
     * @param lender - the address of the lender
     * @param tokenId - the id of the position
     * @param amount - the amount of tokens being deployed to the credit position
     */
    function _tryAddCreditPosition(address lender, uint256 tokenId, uint256 amount) internal {

        // NOTE:
        // Check msg.sender has enough gas to make static call to supportsInterface in _safeSupportsInterface
        // Prevents addCreditPosition from being called in the case of insufficient gas
        // Adds up to 0.015 ETH in gas estimation, but actual gas used is much less
        // Calculation: 150_000 * 100 * 1e9 / 1e18= 0.015 ETH
        hasMinGas(150000, 0);

        // Skip if not a contract or contract does not support the interface
        if (
            lender.code.length == 0
            || !_safeSupportsInterface(lender, ICreditStrategyLike.addCreditPosition.selector)
        ) {
            return;
        }

        // Make the call if checks pass
        (bool success, ) = lender.call(
            abi.encodeWithSelector(
                ICreditStrategyLike.addCreditPosition.selector,
                tokenId,
                amount
            )
        );

        if (!success) {
            revert LenderIsNotCreditStrategy();
        }
    }

    /**
     * @notice - updates `status` variable in storage if current status is diferent from existing status.
     * @dev - privileged internal function. MUST check params and logic flow before calling
     * @dev - does not save new status if it is the same as current status
     * @return status - the current status of the line after updating
     */
    function _updateStatus(LineLib.STATUS status_) internal returns (LineLib.STATUS) {
        if (status == status_) return status_;
        emit UpdateStatus(uint256(status_));
        return (status = status_);
    }

    /**
     * @notice - Generates position id and stores lender's position
     * @dev - positions have unique composite-index on [owner, lenderAddress, tokenAddress]
     * @dev - privileged internal function. MUST check params and logic flow before calling
     * @param tokenId - id of 721 that will own and manage position
     * @param token - ERC20 token that is being lent and borrower
     * @param amount - amount of tokens lender will initially deposit
     */
    function _createCredit(
        uint256 tokenId,
        address token,
        uint256 amount,
        bool isRestricted,
        uint16 earlyWithdrawalFee,
        uint256 deadline
    ) internal {
        credits[tokenId] =
            CreditLib.create(amount, tokenId, token, address(oracle), isRestricted, earlyWithdrawalFee, deadline);

        ids.push(tokenId); // add lender to end of repayment queue

        // if positions was 1st in Q, cycle to next valid position
        if (ids[0] == 0) ids.stepQ();

        ++count;
    }

    /**
     * @dev - Reduces `principal` and/or `interestAccrued` on a credit line.
     *             Expects checks for conditions of repaying and param sanitizing before calling
     *             e.g. early repayment of principal, tokens have actually been paid by borrower, etc.
     * @dev - privileged internal function. MUST check params and logic flow before calling
     * @dev syntatic sugar
     * @param id - position id with all data pertaining to line
     * @param amount - amount of Credit Token being repaid on credit line
     */
    function _repay(Credit storage credit, uint256 id, uint256 amount, address payer) internal {
        CreditLib.repay(credit, fees, id, amount, payer, protocolTreasury());
    }

    /**
     * @notice - accrues token demoninated interest on a lender's position.
     * @dev MUST call any time a position balance or interest rate changes
     * @dev syntatic sugar
     * @param credit - the lender position that is accruing interest
     * @param id - the position id for credit position
     */
    function _accrue(Credit storage credit, uint256 id) internal {
        uint256 accruedToken = _accrueInterest(id, credit.principal, credit.deposit);
        CreditLib.accrue(credit, id, accruedToken);
    }

    /**
     * @notice - checks that a credit line is fully repaid and removes it
     * @dev deletes credit storage. Store any data u might need later in call before _close()
     * @dev - privileged internal function. MUST check params and logic flow before calling
     * @dev - when the line being closed is at the 0-index in the ids array, the null index is replaced using `.stepQ`
     * @param credit - the credit position object to close
     * @param id - the id of the credit position to close
     */
    function _close(Credit storage credit, uint256 id) internal virtual {
        // update position data in state
        if (!credit.isOpen) {
            revert PositionIsClosed();
        }
        if (credit.principal != 0) {
            revert CloseFailedWithPrincipal();
        }

        credit.isOpen = false;

        // nullify the element for `id`
        ids.removePosition(id);

        // if positions was 1st in Q, cycle to next valid position
        if (ids[0] == 0) ids.stepQ();

        --count;

        // If all credit lines are closed the the overall Line of Credit facility is declared 'repaid'.
        if (count == 0) {
            _updateStatus(LineLib.STATUS.REPAID);
        }

        emit CloseCreditPosition(id);
    }

    /**
     * @notice - Insert `p` into the next availble FIFO position in the repayment queue
     *            - once earliest slot is found, swap places with `p` and position in slot.
     * @dev - privileged internal function. MUST check params and logic flow before calling
     * @param p - position id that we are trying to find appropriate place for
     */
    function _sortIntoQ(uint256 p) internal {
        uint256 lastSpot = ids.length - 1;
        uint256 nextQSpot = lastSpot;
        uint256 id;
        for (uint256 i; i <= lastSpot; ++i) {
            id = ids[i];
            if (p != id) {
                if (
                    id == 0 // deleted element. In the middle of the q because it was closed.
                        || nextQSpot != lastSpot // position already found. skip to find `p` asap
                        || credits[id].principal != 0 //`id` should be placed before `p`
                ) continue;
                nextQSpot = i; // index of first undrawn line found
            } else {
                // nothing to update
                if (nextQSpot == lastSpot) return; // nothing to update
                // get id value being swapped with `p`
                uint256 oldPositionId = ids[nextQSpot];
                // swap positions
                ids[i] = oldPositionId; // id put into old `p` position
                ids[nextQSpot] = p; // p put at target index

                emit SortedIntoQ(p, nextQSpot, i, oldPositionId);
            }
        }
    }

    /* GETTERS */

    /**
     * @notice - returns the credit position data for a given tokenId
     * @param tokenId - id of credit position
     * @return (Credit memory) - details about given credit position
     */
    function getCreditPosition(uint256 tokenId) public view returns (Credit memory) {
        return (credits[tokenId]);
    }

    /**
     * @notice - returns the treasury address
     * @return - address of the treasury
     */
    function protocolTreasury() public view returns (address) {
        return lineFactory.protocolTreasury();
    }

    /**
     * @notice - returns the line factory address
     * @return - address of the line factory
     */
    function getLineFactory() external view returns (address) {
        return address(lineFactory);
    }

    /**
     * @notice - returns the interest accrued on a credit position
     * @param id - id of credit position
     * @return   - interest accrued on credit position
     */
    function interestAccrued(uint256 id) external view returns (uint256) {
        Credit storage credit = credits[id];
        return credit.interestAccrued + _getAccruedInterest(id, credit.principal, credit.deposit);
    }

    /**
     * @notice - getter for amount of active ids + total ids in list
     * @return - (uint256, uint256) - active credit lines, total length
     */
    function counts() external view returns (uint256, uint256) {
        return (count, ids.length);
    }

    /**
     * @notice - how many tokens can be withdrawn from positions by borrower or lender
     * @return - (uint256, uint256) - remaining deposit, claimable interest
     */
    function available(uint256 id) external view returns (uint256, uint256) {
        return (credits[id].deposit - credits[id].principal, credits[id].interestRepaid);
    }

    /**
     * notice  - origination, swap, and servicing fees on the line
     * @return - (origination, swap, servicing fees)
     */
    function getFees() external view returns (Fees memory) {
        return fees;
    }

    /**
     * @notice - info on the next lender position that must be repaid
     * @return - (bytes32, address, address, uint, uint) - id, lender, token, principal, interestAccrued
     */
    function nextInQ() external view returns (uint256, uint256, address, uint256, uint256, uint256, uint128, uint128) {
        uint256 next = ids[0];
        Credit storage credit = credits[next];
        // Add to docs that this view revertts if no queue
        if (credit.principal == 0) {
            revert NoQueue();
        }
        (uint128 dRate, uint128 fRate) = getRates(next);
        return (
            next,
            credit.tokenId,
            credit.token,
            credit.principal,
            credit.deposit,
            credit.interestAccrued + _getAccruedInterest(next, credit.principal, credit.deposit),
            dRate,
            fRate
        );
    }
}
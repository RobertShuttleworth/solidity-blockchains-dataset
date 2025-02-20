// SPDX-License-Identifier: GPL-3.0
// Copyright: https://github.com/credit-cooperative/Line-Of-Credit-v2/blob/master/COPYRIGHT.md

pragma solidity 0.8.25;

import {MutualConsent} from "./lib_Line-Of-Credit-v2_contracts_utils_MutualConsent.sol";
import {ReentrancyGuard} from "./lib_openzeppelin-contracts_contracts_utils_ReentrancyGuard.sol";
import {MutualConsent} from "./lib_Line-Of-Credit-v2_contracts_utils_MutualConsent.sol";
import {OTCState, OTCLib} from "./lib_Line-Of-Credit-v2_contracts_utils_OTCLib.sol";
import {LineLib} from "./lib_Line-Of-Credit-v2_contracts_utils_LineLib.sol";
import {IERC20} from "./lib_openzeppelin-contracts_contracts_token_ERC20_IERC20.sol";
import {IWETH9} from "./lib_Line-Of-Credit-v2_contracts_interfaces_IWETH9.sol";
import {SafeERC20} from "./lib_openzeppelin-contracts_contracts_token_ERC20_utils_SafeERC20.sol";
import {ISpigot} from "./lib_Line-Of-Credit-v2_contracts_interfaces_ISpigot.sol";
import {IEscrow} from "./lib_Line-Of-Credit-v2_contracts_interfaces_IEscrow.sol";
import {ILineOfCredit} from "./lib_Line-Of-Credit-v2_contracts_interfaces_ILineOfCredit.sol";
import {ISpigotedLine} from "./lib_Line-Of-Credit-v2_contracts_interfaces_ISpigotedLine.sol";
import {IEscrowedLine} from "./lib_Line-Of-Credit-v2_contracts_interfaces_IEscrowedLine.sol";
import {ISecuredLine} from "./lib_Line-Of-Credit-v2_contracts_interfaces_ISecuredLine.sol";
import {IMutualConsent} from "./lib_Line-Of-Credit-v2_contracts_interfaces_IMutualConsent.sol";
import {IOTC} from "./lib_Line-Of-Credit-v2_contracts_interfaces_IOTC.sol";
import {DiscreteDistribution, BeneficiaryData} from "./lib_Line-Of-Credit-v2_contracts_utils_DiscreteDistribution.sol";
import {FeesLib} from "./lib_Line-Of-Credit-v2_contracts_utils_FeesLib.sol";

struct SpigotState {
    /// @notice Functions that the operator is allowed to run on all borrower contracts controlled by the Spigot
    mapping(bytes4 => bool) whitelistedFunctions; // function -> allowed
    /// @notice Configurations for borrower contracts related to the split, access control to claiming spigot tokens and transfer of Spigot ownership
    mapping(address => ISpigot.Setting) settings; // borrower contract -> settings
}

/**
 * @title  - Spigot
 * @author - Credit Cooperative
 * @notice - Governs the secure escrowing and splittling of onchain cash flows from a borrower's smart contracts.
 */
contract Spigot is ISpigot, ReentrancyGuard, MutualConsent, DiscreteDistribution {
    using OTCLib for OTCState;
    using SafeERC20 for IERC20;

    SpigotState private state;
    OTCState private otcState;
    IWETH9 private weth;

    uint8 constant MAX_SPLIT = 100;
    uint96 constant defaultAllocation = 10000;
    bool init = false;

    // Track beneficiary swaps since we cannot call registerPayment for repaying beneficiary debt w/ traded tokens

    /// @notice - totat amount of a specific token that has been traded for
    /// param address - token address
    mapping(address => uint256) public totalBennyAmountTradedFor;

    /// @notice - amount of a token that has been traded for a specific beneficiary
    /// param address - beneficiary address
    mapping(address => uint256) public bennyAmountTradedFor;

    // Used for factory deployment via erc-1167 to replace constructor
    bool private initializedFromFactory = false;
    bool private ownershipTransferedToLine = false;

    constructor() {}

    /**
     * @notice  - Initialize Spigot contract
     * @dev     - Spigot is deployed and initialized from SpigotFactory
     * @param _operator          - operator role of spigot
     * @param defaultBeneficiary - owner of the spigot (i.e. LineOfCredit)
     * @param _weth              - weth address so when the spigot receives eth it can swap for weth
     */
    function initializeFromFactory(address _operator, BeneficiaryData memory defaultBeneficiary, address _weth)
        external
    {
        if (initializedFromFactory) {
            revert AlreadyInitialized();
        }

        initializedFromFactory = true;
        weth = IWETH9(_weth);

        BeneficiaryData[] memory beneficiaries_ = new BeneficiaryData[](0);
        address[] memory tokens = new address[](0);
        _resetBeneficiaries(_operator, defaultBeneficiary, beneficiaries_, tokens);
    }

    //// MODIFIERS /////

    modifier onlyOwnerOrAdmin() {
        if (msg.sender != _owner() && msg.sender != _admin()) revert CallerAccessDenied();
        _;
    }

    modifier onlyOwnerOrServicer() {
        if (msg.sender != _owner() && !_isServicer()) revert CallerAccessDenied();
        _;
    }

    modifier onlyOwner() {
        if (msg.sender != _owner()) revert CallerAccessDenied();
        _;
    }

    ////// PERMISSIONING //////

    function _onlyAdmin() internal view {
        if (msg.sender != _admin()) revert CallerAccessDenied();
    }

    function _onlyBeneficiary(address beneficiary) private view {
        if (_beneficiaryData(beneficiary).poolAddress == address(0)) {
            revert BadBeneficiary();
        }
    }

    function _checkNullAddress(address _address) internal pure {
        if (_address == address(0)) {
            revert CannotBeZeroAddress();
        }
    }

    function _checkNullFunctionData(bytes4 func) internal view {
        if (func == bytes4(0)) {
            revert BadFunction();
        }
    }

    function _cannotExceedMaxSplit(uint8 split) internal pure {
        if (split > MAX_SPLIT) {
            revert InvalidSplit();
        }
    }

    function _onlyOperatorOrServicer() internal view {
        if (msg.sender != _operator() && !_isServicer()) {
            revert CallerAccessDenied();
        }
    }

    function _onlyBorrowerOrServicer() internal view {
        if (msg.sender != _borrower() && !_isServicer()) {
            revert CallerAccessDenied();
        }
    }

    function _onlyBorrowerOrAdmin() internal view {
        if (msg.sender != _borrower() && msg.sender != _admin()) {
            revert CallerAccessDenied();
        }
    }

    /// @notice - if smart escrow is being used, certain functions need to be called from the escrow contract
    function _isSmartEscrow(address sender) internal returns (bool) {
        if (
            _borrower() == address(IEscrowedLine(_owner()).escrow())
                && sender == IEscrow(IEscrowedLine(_owner()).escrow()).borrower()
        ) {
            return true;
        }
        return false;
    }

    ///// GETTERS SPIGOT ADDRESSES /////

    /**
     * @notice - returns all beneficiaries
     * @return - array of addresses of beneficiaries
     */
    function beneficiaries() external view returns (address[] memory) {
        return _beneficiaries();
    }

    /**
     * @notice - returns the owner of the spigot, usually the line of credit
     * @return - address of the owner
     */
    function owner() external view returns (address) {
        return _owner();
    }

    /**
     * @notice - returns the operator of the spigot
     * @return - address of the operator
     */
    function operator() external view returns (address) {
        return _operator();
    }

    /// GETTERS FOR LINE ADDRESSES AND INFO ////

    /// @notice - returns true if `msg.sender` == servicer otherwise returns false
    function _isServicer() internal view returns (bool) {
        return ILineOfCredit(_owner()).isServicer(msg.sender);
    }

    /**
     * @notice - returns the admin of the line of credit
     * @return - address of the admin
     */
    function _admin() internal view returns (address) {
        return ILineOfCredit(_owner()).admin();
    }
    /**
     * @notice - returns the borrower of the line of credit
     * @return - address of the borrower
     */

    function _borrower() internal view returns (address) {
        return ILineOfCredit(_owner()).borrower();
    }

    /**
     * @notice - returns the fees for the line of credit
     * @return - fees struct
     */
    function _getFees() internal view returns (ILineOfCredit.Fees memory) {
        return ILineOfCredit(_owner()).getFees();
    }

    /**
     * @notice - returns the protocol treasury address
     * @return - address of the protocol treasury
     */
    function _getProtocolTreasury() internal view returns (address) {
        return ILineOfCredit(_owner()).protocolTreasury();
    }

    /**
     * @notice - returns the status of the corresponding line of credit
     * @return - status of the line of credit
     */
    function _getStatus() internal returns (LineLib.STATUS) {
        return ILineOfCredit(_owner()).status();
    }

    /// @notice - increments the nonce of the line of credit when a new state change is made
    function _incrementNonce() internal {
        ISecuredLine(_owner()).incrementNonce();
    }

    /**
     * @notice - checks oustanding debt, deadline and collateral and returns a status
     * @return - status of the line of credit
     */
    function _healthcheck() internal returns (LineLib.STATUS) {
        return ILineOfCredit(_owner()).healthcheck();
    }

    /**
     * @notice - returns address of the 0x proxy address
     * @return - address of the 0x proxy
     */
    function _swapTarget() internal returns (address) {
        return ISpigotedLine(_owner()).swapTarget();
    }

    // ##########################
    // #####     Claimer    #####
    // ##########################

    /**
     * @notice  - Claims spigot tokens from the Spigoted borrower contract and stores them for the Owner and Operator to withdraw later.
     *          - Accepts both push (tokens sent directly to Spigot) and pull payments (Spigot calls borrower contract to claim tokens)
     *          - Calls predefined function in contract settings to claim tokens.
     *          - Automatically sends portion to Treasury and then stores Owner and Operator shares
     *          - There is no conversion or trade of spigot tokens.
     * @dev     - Assumes the only side effect of calling claimFunc on borrowerContract is we receive new tokens.
     *          - Any other side effects could be dangerous to the Spigot or upstream contracts.
     * @dev     - callable by anyone
     * @param borrowerContract   - Contract with registered settings to claim tokens from
     * @param data              - Transaction data, including function signature, to properly claim tokens on borrowerContract
     * @return claimed          -  The amount of spigot tokens claimed from borrowerContract and split between `owner` and `treasury`
     */
    function pullTokens(address borrowerContract, address token, bytes calldata data)
        external
        nonReentrant
        returns (uint256 claimed)
    {
        _onlyOperatorOrServicer();
        bytes4 claimFunction = state.settings[borrowerContract].claimFunction;
        _checkNullFunctionData(state.settings[borrowerContract].transferOwnerFunction);
        _checkNullFunctionData(claimFunction);

        uint256 existingBalance = IERC20(token).balanceOf(address(this));
        // pull payments
        if (bytes4(data) != claimFunction) revert BadFunction();

        (bool claimSuccess,) = borrowerContract.call(data);
        if (!claimSuccess) revert ClaimFailed();

        // claimed = total balance - existing balance
        claimed = IERC20(token).balanceOf(address(this)) - existingBalance;
        // underflow revert ensures we have more tokens than we started with and actually claimed tokens

        if (claimed == 0) revert NoClaimableTokens();

        // splits cash flow according to Spigot settings
        uint256 operatorTokens = claimed - (claimed * state.settings[borrowerContract].ownerSplit) / MAX_SPLIT;

        _reserveTokens(token, operatorTokens);

        emit ClaimTokens(token, claimed, operatorTokens, borrowerContract);
    }

    /**
     * @notice - So the servicer can just pass in any data.
     *           We need to enforce that they are passing in data that will call the function
     *           that the beneficiary has set as their repayment function.
     *           We grab the selector from the incoming calldata and compare to the beneficiary's repayment function
     */
    function _repayBeneficiary(
        bytes calldata functionData,
        address beneficiary,
        BeneficiaryData storage beneficiaryData,
        uint256 amount,
        uint256 servicingFeeAmount
    ) internal {
        address poolAddress = beneficiaryData.poolAddress;
        IERC20 creditToken = IERC20(beneficiaryData.creditToken);
        if (bytes4(functionData) != beneficiaryData.repaymentFunc) {
            revert BadFunction();
        }

        uint256 debtOwed = _getDebtOwed(beneficiary);

        uint256 beforeRepayment = creditToken.balanceOf(address(this));
        creditToken.forceApprove(poolAddress, amount);

        // send servicingFee to protocolTreasury
        if (servicingFeeAmount != 0) {
            creditToken.safeTransfer(_getProtocolTreasury(), servicingFeeAmount);
        }

        // repay beneficiary debt to poolAddress
        (bool success,) = poolAddress.call(functionData);
        if (!success) {
            revert OperatorFnCallFailed();
        }

        // set allowance to 0 after repayment
        IERC20(beneficiaryData.creditToken).forceApprove(beneficiaryData.poolAddress, 0);

        uint256 repaymentAmount = beforeRepayment - creditToken.balanceOf(address(this));

        // check that do not overpay debt owed
        if (repaymentAmount > debtOwed + servicingFeeAmount) {
            revert CannotOverpayBeneficiaryDebt();
        }

        // ensure that not more than `amount` has left the contract
        if (repaymentAmount != amount) {
            revert InsufficientFunds();
        }
    }

    /**
     * @notice - Repay beneficiary debt using traded beneficiary tokens.
     * @dev    - only callable by borrower or servicer role
     * @dev    - cannot repay in excess of beneficiary debt owed. Excess tokens are returned to the Spigot for distribution.
     * @param functionData  - the function data to call on the beneficiary pool in order to repay (encoded function selector and arguments)
     * @param beneficiary   - the beneficiary we are repaying
     */
    function repayBeneficiaryWithTradedTokens(bytes calldata functionData, address beneficiary) external {
        _onlyBorrowerOrServicer();
        BeneficiaryData storage beneficiaryData = _beneficiaryData(beneficiary);
        uint256 debtOwed = _getDebtOwed(beneficiary);
        uint256 tradedAmount = bennyAmountTradedFor[beneficiary];

        _checkNullAddress(beneficiaryData.poolAddress);

        if (tradedAmount == 0) {
            revert NoTradedTokens();
        }

        // determine repayment amount
        uint256 repaymentAmount;
        if (tradedAmount > debtOwed) {
            repaymentAmount = debtOwed;
        } else {
            repaymentAmount = tradedAmount;
        }

        // reset the amount traded for the beneficiary
        totalBennyAmountTradedFor[beneficiaryData.creditToken] -= tradedAmount;
        bennyAmountTradedFor[beneficiary] = 0;

        _repayBeneficiary(functionData, beneficiary, beneficiaryData, repaymentAmount, 0);
    }

    /**
     * @notice - Repay beneficiary debt using beneficiary tokens.
     * @dev    - only callable by borrower or servicer role
     * @dev    - cannot repay in excess of beneficiary debt owed
     * @param functionData  - the function data to call on the beneficiary pool in order to repay (encoded function selector and arguments) (repayment amount excludes servicing fee)
     * @param beneficiary   - the beneficiary we are repaying
     * @param amount        - amount of token we are repaying (includes the servicing fee)
     */
    function repayBeneficiary(bytes calldata functionData, address beneficiary, uint256 amount) external {
        _onlyBorrowerOrServicer();

        // must repay with traded tokens before repaying with beneficiary tokens
        address beneficiaryCreditToken = _beneficiaryData(beneficiary).creditToken;
        if (totalBennyAmountTradedFor[beneficiaryCreditToken] != 0) {
            revert MustRepayWithTradedTokens();
        }

        BeneficiaryData storage beneficiaryData = _beneficiaryData(beneficiary);

        _checkNullAddress(beneficiaryData.poolAddress);

        uint256 debtOwed = _getDebtOwed(beneficiary);
        uint256 servicingFeeAmount = FeesLib._calculateServicingFeeFromAmount(_getFees(), amount);

        // if amount is greater than total owed, adjust amount to be total owed
        if (amount > debtOwed + servicingFeeAmount) {
            servicingFeeAmount = FeesLib._calculateServicingFee(_getFees(), debtOwed);
            amount = debtOwed + servicingFeeAmount;
        }

        _registerRepayment(beneficiaryData.creditToken, beneficiary, amount);
        _repayBeneficiary(functionData, beneficiary, beneficiaryData, amount, servicingFeeAmount);
    }

    /**
     * @notice  - trades tokens assigned for beneficiaries for the proper credit token
     * @notice  - no swap fee because the front end is where we take the fee
     * @notice  - servicing fee is taken from the amount received
     * @dev     - callable by admin
     * @param beneficiary   - the beneficiary we are trading on behalf of
     * @param sellToken     - the token we are trading
     * @param sellAmount    - amount of token we are trading
     * @param minBuyAmount  - the minimun amount of the buy token we are willing to buy
     * @param zeroExTradeData - trade data for ZeroEx
     */
    function tradeAndDistribute(
        address beneficiary,
        address sellToken,
        uint256 sellAmount,
        uint256 minBuyAmount,
        bytes calldata zeroExTradeData
    ) external {
        _onlyAdmin();
        address beneficiaryCreditToken = _beneficiaryData(beneficiary).creditToken;
        if (beneficiaryCreditToken == sellToken) {
            revert InvalidToken();
        }
        uint256 oldTokens = LineLib.getBalance(beneficiaryCreditToken);
        uint256 sellBalanceBefore = LineLib.getBalance(sellToken);

        _registerRepayment(sellToken, beneficiary, sellAmount);

        address swapTarget = _swapTarget();
        IERC20(sellToken).forceApprove(swapTarget, sellAmount);

        (bool success,) = swapTarget.call(zeroExTradeData);
        if (!success) {
            revert TradeFailed();
        }

        // set allowance to 0 after trade
        IERC20(sellToken).forceApprove(_swapTarget(), 0);

        // NOTE: amountSold = sellBalanceBefore- IERC20(sellToken).balanceOf(address(this));
        if (sellBalanceBefore - LineLib.getBalance(sellToken) > sellAmount) {
            revert InsufficientFunds();
        }

        uint256 boughtTokens = LineLib.getBalance(beneficiaryCreditToken) - oldTokens;
        if (boughtTokens < minBuyAmount) revert InsufficientFunds();

        // deduct servicing fee from boughtTokens
        uint256 boughtTokensLessServicingFees = _serviceFeeOnTradedTokens(beneficiary, boughtTokens);

        bennyAmountTradedFor[beneficiary] += boughtTokensLessServicingFees;
        totalBennyAmountTradedFor[beneficiaryCreditToken] += boughtTokensLessServicingFees;
    }

    function _serviceFeeOnTradedTokens(address beneficiary, uint256 amount) internal returns (uint256) {
        BeneficiaryData storage beneficiaryData = _beneficiaryData(beneficiary);
        uint256 debtOwed = _getDebtOwed(beneficiary);
        uint256 servicingFeeAmount = FeesLib._calculateServicingFeeFromAmount(_getFees(), amount);

        // if amount is greater than total owed, adjust amount to be total owed
        if (amount > debtOwed + servicingFeeAmount) {
            servicingFeeAmount = FeesLib._calculateServicingFee(_getFees(), debtOwed);
        }

        // transfer servicing fee to protocol treasury address
        LineLib.sendOutTokenOrETH(beneficiaryData.creditToken, _getProtocolTreasury(), servicingFeeAmount);

        // return tokens remaining in Spigot after servicing fee is taken
        return amount - servicingFeeAmount;
    }

    /**
     * @notice  - does an otc swap with a counterparty
     * @notice  - both `servicingFee` and `swapFee` are taken from the amount received for all beneficiaries except the default beneficiary
     * @dev     - callable by admin and counterparty mutual consent
     * @param beneficiary  - the beneficiary we are trading on behalf of
     * @param oracle       - used to price the assets going in and out
     * @param otc          - data that contains trade info
     */
    function otcSwap(address beneficiary, address oracle, IOTC.OTC memory otc)
        external
        mutualConsent(_admin(), otc.counterparty)
    {
        BeneficiaryData storage bennyInfo = _beneficiaryData(beneficiary);
        bool isOwner = beneficiary == _owner();

        _registerRepayment(otc.tokenGoingOut, beneficiary, otc.tokenGoingOutAmount);

        if (!isOwner && otc.tokenComingIn != bennyInfo.creditToken) {
            revert InvalidToken();
        }

        uint256 amountReceived = otcState.otcSwap(otc, _getFees(), oracle, _getProtocolTreasury());

        if (!isOwner) {
            amountReceived = _serviceFeeOnTradedTokens(beneficiary, amountReceived);
        }

        bennyAmountTradedFor[beneficiary] += amountReceived;
        totalBennyAmountTradedFor[otc.tokenComingIn] += amountReceived;
    }

    /**
     * @notice  - Allows Spigot Owner to claim escrowed spigot tokens.
     * @dev     - callable by `owner` or `servicer`
     * @param token     - address of spigot token that is being escrowed by spigot
     * @return claimed  -  The amount of tokens claimed by the `owner`
     */
    function claimOwnerTokens(address token) external nonReentrant onlyOwnerOrServicer returns (uint256 claimed) {
        address owner_ = _owner();
        uint256 tradedAmount = bennyAmountTradedFor[owner_];
        uint256 totalTradedAmount = totalBennyAmountTradedFor[token];
        claimed = _repayableAmountOf(token, owner_);

        // Cannot claim if there are no claimable tokens
        if (claimed == 0 && tradedAmount == 0) return 0;

        // Can only claim defaultBeneficiary's traded tokens
        if (totalTradedAmount > 0 && tradedAmount != totalTradedAmount) {
            revert CannotClaimBeneficiaryTradedTokens();
        }

        // reset the amount traded for the beneficiary and token to zero
        if (tradedAmount > 0) {
            claimed = tradedAmount;
            bennyAmountTradedFor[owner_] = 0;
            totalBennyAmountTradedFor[token] = 0;
        } else {
            // only register payment for `claimed` and not the `tradedAmount` because the `tradedAmount` is already accounted for
            _registerRepayment(token, owner_, claimed);
        }

        emit ClaimOwnerTokens(token, claimed, owner_);

        IERC20(token).safeTransfer(owner_, claimed);
    }

    /**
     * @notice - Allows Spigot Operator to claim escrowed spigot tokens
     * @dev    - callable by `operator` and `servicer`
     * @param token    - address of spigot token that is being escrowed by spigot
     * @return claimed -  The amount of tokens claimed by the `operator`
     */
    function claimOperatorTokens(address token) external nonReentrant returns (uint256 claimed) {
        _onlyOperatorOrServicer();
        claimed = _operatorTokens(token);
        address operator_ = _operator();
        if (claimed == 0) return 0;

        _releaseTokens(token, claimed);

        emit ClaimOperatorTokens(token, claimed, operator_);

        IERC20(token).safeTransfer(operator_, claimed);
    }

    /**
     * @notice  - sweeps owner and operator tokens to destination address
     * @dev     - callable by `owner` `operator` `servicer` `borrower` and `admin`
     * @param token     - address of token that is being swept
     * @param to  -  destination of the swept tokens
     * @param operatorTokens - amount being sept
     * @param ownerTokens - amount being swept
     */
    function sweepOwnerOperatorTokens(address token, address to)
        external
        nonReentrant
        returns (uint256 operatorTokens, uint256 ownerTokens)
    {
        address borrower_ = _borrower();
        address operator_ = _operator();
        address owner_ = _owner();
        bool isServicer_ = _isServicer();

        if (msg.sender != borrower_ && msg.sender != operator_ && !isServicer_) {
            revert CallerAccessDenied();
        }

        if (_getStatus() != LineLib.STATUS.REPAID || hasBeneficiaryDebtOutstanding()) {
            revert BadStatus();
        }

        ownerTokens = _repayableAmountOf(token, owner_);
        if (ownerTokens != 0) {
            _registerRepayment(token, owner_, ownerTokens);
            emit ClaimOwnerTokens(token, ownerTokens, to);
        }

        operatorTokens = _operatorTokens(token);
        if (operatorTokens != 0) {
            _releaseTokens(token, operatorTokens);
            emit ClaimOperatorTokens(token, operatorTokens, to);
        }

        if (ownerTokens == 0 && operatorTokens == 0) {
            return (0, 0);
        }

        if ((msg.sender == borrower_ || msg.sender == operator_) || (isServicer_ && to == borrower_)) {
            LineLib.sendOutTokenOrETH(token, to, ownerTokens + operatorTokens);
        } else {
            revert CallerAccessDenied();
        }
    }

    /*//////////////////////////////////////////////////////
                       // ADMIN FUNCTIONS //
    //////////////////////////////////////////////////////*/

    function _hasOutstandingDebt() internal view {
        (uint256 count,) = ILineOfCredit(_owner()).counts();

        if (count != 0) {
            revert LineHasActiveCreditPositions(count);
        }

        if (hasBeneficiaryDebtOutstanding()) {
            revert BeneficiaryDebtOutstanding();
        }
    }

    /**
     * @notice - sets up the beneficiaries and their allocations
     * @dev    - any funds present in the contract will be distributed among the beneficiaries according to their allocation
     * @param defaultBeneficiary - beneficiary that receives unassigned funds once other beneficiaries are repaid
     * @param beneficiaries_ - beneficiaries (excluding default beneficiary) and their allocations
     * @param tokens - the tokens to be reassigned to the default beneficiary upon reset
     */
    function resetBeneficiaries(
        address operator,
        BeneficiaryData memory defaultBeneficiary,
        BeneficiaryData[] calldata beneficiaries_,
        address[] memory tokens
    ) external {
        _hasOutstandingDebt();
        if (!_isSmartEscrow(msg.sender)) {
            _onlyBorrowerOrAdmin();
        }
        address owner_ = _owner();

        // Reactivate line
        if (_getStatus() != LineLib.STATUS.ACTIVE) {
            ISecuredLine(owner_).activateLine();
        }

        if (IMutualConsent(owner_).proposalCount() != 0) {
            ISecuredLine(owner_).clearProposals();
        }
        if (defaultBeneficiary.beneficiary != owner_) {
            revert LineMustBeDefaultBeneficiary(defaultBeneficiary.beneficiary);
        }

        _resetBeneficiaries(operator, defaultBeneficiary, beneficiaries_, tokens);
    }

    /**
     * @notice - reassigns tokens to the default beneficiary
     * @dev    - reassigns all remaining tokens to the beneficiary by updating the `reassignedTokens` variable
     * @dev    - adjusts the total allocation modifier so distributions do not take the beneficiary into account in the future
     * @dev    - flags the `repaidAmounts` variable for the beneficiary to mark that the beneficiary has an allocation of 0 for the reassigned token
     * @dev    - the allocation of the beneficiary is implicitly redistributed amongst all other beneficiaries
     * @param beneficiary - the beneficiary to reassign tokens to
     * @param tokens - the tokens to reassign
     */
    function reassignTokens(address beneficiary, address[] calldata tokens) external {
        _onlyAdmin();
        uint256 debtOwed = _getDebtOwed(beneficiary);
        if (debtOwed != 0) revert BeneficiaryDebtOutstanding();
        uint256 len = tokens.length;
        for (uint256 i = 0; i < len; i++) {
            // reset the amount traded for the beneficiary
            uint256 bennyAmountRemaining = bennyAmountTradedFor[beneficiary];
            bennyAmountTradedFor[beneficiary] = 0;
            totalBennyAmountTradedFor[tokens[i]] -= bennyAmountRemaining;

            // reassign beneficiary tokens to default beneficiary
            _reassignTokens(tokens[i], beneficiary);
        }
    }

    /**
     * @notice - Only in case of emergency, we set beneficiary debt to 0
     * @dev    - callable by admin
     * @param beneficiary - beneficiary to void the debt of
     */
    function impairBeneficiaryDebtOwed(address beneficiary) external {
        _onlyAdmin();
        _voidDebt(beneficiary);
    }

    /**
     * @notice  - Allows admin to recover tokens on behalf of a 3rd party beneficiary
     * @dev     - callable by `admin`
     * @param beneficiary - the beneficiary to recover tokens from
     * @param token - the token to recover
     * @param to - the address to send the recovered tokens to
     */
    function recoverBeneficiaryTokens(address beneficiary, address token, address to) external {
        _onlyAdmin();
        _checkNullAddress(beneficiary);
        _checkNullAddress(token);

        if (_getDebtOwed(beneficiary) != 0) {
            revert BeneficiaryDebtOutstanding();
        }
        uint256 recoveredTokens = _repayableAmountOf(token, beneficiary);
        _registerRepayment(token, beneficiary, recoveredTokens);
        IERC20(token).safeTransfer(to, recoveredTokens);
    }

    /**
     * @notice  - Allows admin to recover tokens on behalf of a line of credit
     * @dev     - callable by `admin`
     * @param token - the token to recover
     * @param to - the address to send the recovered tokens to
     */
    function recoverSpigotTokens(address token, address to) external {
        address owner_ = _owner();
        LineLib.STATUS s = ILineOfCredit(owner_).healthcheck();
        _onlyAdmin();
        if (s != LineLib.STATUS.ABORTED) {
            revert CallerAccessDenied();
        }
        IERC20(token).safeTransfer(to, IERC20(token).balanceOf(address(this)));
    }

    /**
     * @notice - the below functions will be replaced when there are adapters for beneficiaries. These exist solely to test the accounting functionality of the spigot
     * @dev - callable by admin
     * @param beneficiary - the beneficiary to update
     * @param repaymentFunc - the function to call on the poolAddress to repay the beneficiary
     */
    function updateBeneficiaryRepaymentFunc(address beneficiary, bytes4 repaymentFunc) external {
        _onlyAdmin();
        _onlyBeneficiary(beneficiary);
        _checkNullFunctionData(repaymentFunc);

        _beneficiaryData(beneficiary).repaymentFunc = repaymentFunc;
    }

    /**
     * @notice - allows admin to change what address a beneficiary want to be repaid to
     * @dev - callable by admin
     * @param beneficiary - the beneficiary to update
     * @param poolAddress - the address to repay the beneficiary
     */
    function updateBeneficiaryPoolAddress(address beneficiary, address poolAddress) external {
        _onlyAdmin();
        _onlyBeneficiary(beneficiary);
        _checkNullAddress(poolAddress);
        _beneficiaryData(beneficiary).poolAddress = poolAddress;
    }

    /*//////////////////////////////////////////////////////
                        I N T E R N A L
    //////////////////////////////////////////////////////*/

    // ##########################
    // ##########################
    // #####  OPERATOR    #####
    // ##########################

    /**
     * @notice  - Allows Operator to call whitelisted functions on borrower contracts to maintain their product
     *          - while still allowing Spigot Owner to receive its cash flow
     * @dev     - cannot call borrowerContracts claim or transferOwner functions
     * @dev     - callable by `operator`
     * @param borrowerContract   - contract to call. Must have existing settings added by Owner
     * @param data              - tx data, including function signature, to call contract with
     */
    function operate(address borrowerContract, bytes calldata data) external nonReentrant returns (bool) {
        if (msg.sender != _operator()) {
            revert CallerAccessDenied();
        }

        // extract function signature from tx data and check whitelist
        bytes4 func = bytes4(data);

        if (!state.whitelistedFunctions[func]) {
            revert OperatorFnNotWhitelisted();
        }

        // cant claim tokens via operate() because that fucks up accounting logic. Owner shouldn't whitelist it anyway but just in case
        // also can't transfer ownership so Owner retains control of borrower contract
        if (
            func == state.settings[borrowerContract].claimFunction
                || func == state.settings[borrowerContract].transferOwnerFunction
        ) {
            revert OperatorFnNotValid();
        }

        (bool success,) = borrowerContract.call(data);
        if (!success) {
            revert OperatorFnCallFailed();
        }
        return true;
    }

    // ##########################
    // #####    Maintainer  #####
    // ##########################

    /**
     * @notice  - allows admin or servicer to add a new borrower contract to the spigot
     * @dev     - borrowerContract cannot be address(this)
     * @dev     - callable by `owner`
     * @param borrowerContract   - smart contract to claim tokens from
     * @param setting           - Spigot settings for smart contract
     */
    function addSpigot(address borrowerContract, Setting memory setting) external {
        if (_admin() != msg.sender && !_isServicer()) {
            revert CallerAccessDenied();
        }
        if (borrowerContract == address(this)) {
            revert InvalidBorrowerContract();
        }
        // spigot setting already exists
        if (state.settings[borrowerContract].transferOwnerFunction != bytes4(0)) {
            revert SpigotSettingsExist();
        }

        // must set transfer func
        _checkNullFunctionData(setting.transferOwnerFunction);

        // owner split cannot exceed max split
        _cannotExceedMaxSplit(setting.ownerSplit);

        state.settings[borrowerContract] = setting;
        emit AddSpigot(borrowerContract, setting.ownerSplit, setting.claimFunction, setting.transferOwnerFunction);
    }

    /**
     * @notice  - Uses predefined function in borrowerContract settings to transfer complete control and ownership from this Spigot to the Operator
     * @dev     - borrowerContract's transfer func MUST only accept one paramteter which is the new owner's address.
     * @dev     - callable by `owner` `operator` `borrower` and `admin` depending on the status of the line of credit
     * @param borrowerContract - smart contract to transfer ownership of
     */
    function removeSpigot(address borrowerContract) external {
        address owner_ = _owner();
        address operator_ = _operator();
        address borrower_ = _borrower();
        address admin_ = _admin();
        LineLib.STATUS status = ILineOfCredit(owner_).healthcheck();

        if (
            (status == LineLib.STATUS.REPAID && (msg.sender == borrower_ || (_isServicer()) || msg.sender == operator_))
                || (status == LineLib.STATUS.LIQUIDATABLE && msg.sender == admin_)
                || (
                    status == LineLib.STATUS.ABORTED && (msg.sender == admin_ || msg.sender == borrower_)
                )
        ) {
            (bool success,) = borrowerContract.call(
                abi.encodeWithSelector(
                    state.settings[borrowerContract].transferOwnerFunction,
                    operator_ // assume function only takes one param that is new owner address
                )
            );
            require(success);

            delete state.settings[borrowerContract];
            emit RemoveSpigot(borrowerContract);
            return;
        }
        revert CallerAccessDenied();
    }

    /**
     * @notice - Changes the borrower contract split between the Operator and the Line (Owner) based upon the status of the Line of Credit
     * @dev    - callable by borrower or admin
     * @param borrowerContract   - spigot to update
     * @param ownerSplit         - percentage of tokens to send to owner
     */
    function updateBorrowerContractSplit(address borrowerContract, uint8 ownerSplit) external {
        if (!_isSmartEscrow(msg.sender)) {
            _onlyBorrowerOrAdmin();
        }
        _incrementNonce();
        _cannotExceedMaxSplit(ownerSplit);
        if (hasBeneficiaryDebtOutstanding()) {
            revert BeneficiaryDebtOutstanding();
        }
        address owner_ = _owner();
        (uint256 count,) = ILineOfCredit(owner_).counts();
        uint256 lineProposalCount = IMutualConsent(owner_).proposalCount();

        if (msg.sender == _borrower()) {
            if (count != 0) {
                revert LineHasActiveCreditPositions(count);
            }
            if (lineProposalCount != 0) {
                ISecuredLine(_owner()).clearProposals();
            }
            return _updateBorrowerContractSplit(borrowerContract, ownerSplit);
        } else if (_getStatus() == LineLib.STATUS.LIQUIDATABLE) {
            return _updateBorrowerContractSplit(borrowerContract, ownerSplit);
        }
        revert CallerAccessDenied();
    }

    function _updateBorrowerContractSplit(address borrowerContract, uint8 ownerSplit) internal {
        bytes4 transferFunc = state.settings[borrowerContract].transferOwnerFunction;

        _checkNullFunctionData(transferFunc);

        state.settings[borrowerContract].ownerSplit = ownerSplit;
        emit UpdateBorrowerContractSplit(borrowerContract, ownerSplit);
    }

    /**
     * @notice  - Update Owner role of Spigot contract.
     *          - New Owner receives cash flow split and can control Spigot
     * @dev     - callable by `owner`
     * @param newOwner - Address to give control to
     */
    function updateOwner(address newOwner) public returns (bool) {
        if (ownershipTransferedToLine) {
            revert CallerAccessDenied();
        }
        address owner_ = _owner();
        if (msg.sender != owner_) {
            revert CallerAccessDenied();
        }
        ownershipTransferedToLine = true;

        BeneficiaryData memory defaultBeneficiary;
        defaultBeneficiary.beneficiary = newOwner;
        defaultBeneficiary.allocation = defaultAllocation;

        BeneficiaryData[] memory beneficiaries = new BeneficiaryData[](0);
        address[] memory tokens = new address[](0);

        _resetBeneficiaries(_operator(), defaultBeneficiary, beneficiaries, tokens);
        return true;
    }

    /**
     * @notice  - Update Operator role of Spigot contract.
     *          - New Operator can interact with borrower contracts.
     * @dev     - callable by `operator` or `admin` if line is in liquidatable status
     * @param newOperator - Address to give control to
     */
    function updateOperator(address newOperator) external {
        LineLib.STATUS status = ILineOfCredit(_owner()).healthcheck();

        if (
            ((status == LineLib.STATUS.REPAID || status == LineLib.STATUS.ACTIVE) && msg.sender == _operator())
                || status == LineLib.STATUS.LIQUIDATABLE && msg.sender == _admin()
        ) {
            _checkNullAddress(newOperator);

            _distributionData().operator = newOperator;
            emit UpdateOperator(newOperator);
            return;
        }
        revert CallerAccessDenied();
    }

    /**
     * @notice  - Allows Owner to whitelist function methods across all borrower contracts for Operator to call.
     *          - Can whitelist "transfer ownership" functions on borrower contracts
     *          - allowing Spigot to give direct control back to Operator.
     * @dev     - callable by `owner`
     * @param func      - smart contract function signature to whitelist
     * @param allowed   - true/false whether to allow this function to be called by Operator
     */
    function updateWhitelistedFunction(bytes4 func, bool allowed) external {
        _onlyAdmin();
        state.whitelistedFunctions[func] = allowed;
        emit UpdateWhitelistFunction(func, allowed);
    }

    /**
     * @notice  - updates the stablecoins we will allow for otc swap
     * @dev     - callable by admin or owner
     * @param token - the token to whitelist
     * @param includeToken - true to whitelist, false to blacklist
     */
    function updateStableCoinWhitelist(address token, bool includeToken) public onlyOwnerOrAdmin {
        _checkNullAddress(token);
        otcState.stableCoinWhitelist[token] = includeToken;
    }

    /**
     * @notice - allows the line to change the allowed price impact for OTC trades on Spigot contract
     * @dev    - only callable by the line
     * @param allowedPriceImpact - the new price impact that is allowed
     */
    function updateAllowedOTCPriceImpact(uint128 allowedPriceImpact) external onlyOwner {
        otcState.nonStableCoinPriceImpact = allowedPriceImpact;
    }

    // ##########################
    // #####     GETTERS    #####
    // ##########################

    /**
     * @notice  - Retrieve amount of spigot tokens escrowed waiting for claim
     * @param token - token that is being garnished from spigots
     * @return - amount of tokens escrowed for the owner
     */
    function getOwnerTokens(address token) external view returns (uint256) {
        return _repayableAmountOf(token, _owner());
    }

    /**
     * @notice - Retrieve amount of spigot tokens escrowed waiting for claim
     * @param token - token that is being garnished from spigots
     * @return - amount of tokens escrowed for the operator
     */
    function getOperatorTokens(address token) external view returns (uint256) {
        return _operatorTokens(token);
    }

    /**
     * @notice - Retrieve amount of spigot tokens escrowed to a specific beneficiary
     * @param beneficiary - the beneficiary we want to know escrowed amounts
     * @param token - token that is being returned
     * @return - amount of tokens escrowed for the beneficiary
     */
    function getBeneficiaryTokens(address beneficiary, address token) external view returns (uint256) {
        return _repayableAmountOf(token, beneficiary);
    }

    /**
     * @notice - Returns if the function is whitelisted for an Operator to call
     *            - on the spigoted borrower smart contracts.
     * @param func - Function signature to check on whitelist
     * @return - true/false if function is whitelisted
     */
    function isWhitelisted(bytes4 func) external view returns (bool) {
        return state.whitelistedFunctions[func];
    }

    /**
     * @notice - Returns the settings for a borrower contract
     * @param borrowerContract - the borrower contract to get settings for
     * @return - ownerSplit, claimFunction, transferOwnerFunction
     */
    function getSetting(address borrowerContract) external view returns (uint8, bytes4, bytes4) {
        return (
            state.settings[borrowerContract].ownerSplit,
            state.settings[borrowerContract].claimFunction,
            state.settings[borrowerContract].transferOwnerFunction
        );
    }

    /// @notice - returns true if there is any outstanding debt, false if no debt.
    function hasBeneficiaryDebtOutstanding() public view returns (bool) {
        address[] storage beneficiaries_ = _distributionData().beneficiaries;
        uint256 len = beneficiaries_.length;
        for (uint256 i = 0; i < len; i++) {
            if (_getDebtOwed(beneficiaries_[i]) != 0) {
                return true;
            }
        }
        return false;
    }

    function _getDebtOwed(address beneficiary) internal view returns (uint256) {
        if (_beneficiaryData(beneficiary).debtVoided) return 0;
        // get the func
        bytes4 getDebtFunc = _beneficiaryData(beneficiary).getDebtFunc;

        // call the func
        // NOTE: assumes that the only input is the borrower address and the only output is the debt owed in uint
        address poolAddress = _distributionData().data[beneficiary].poolAddress;
        (bool success, bytes memory data) = poolAddress.staticcall(abi.encodeWithSelector(getDebtFunc, _borrower()));

        if (success) {
            uint256 debtOwed = abi.decode(data, (uint256));
            return debtOwed;
        }

        return 0;
    }

    /// @notice if the spigot receives ETH we immediately swap for WETH
    receive() external payable {
        weth.deposit{value: msg.value}();
    }

    ///////////////////////// VIEW FUNCS //////////////////////////

    /**
     * @notice gets the default beneficiary data for credit token and allocation
     * @return allocation - the default allocation of tokens that gets set aside for defualt beneficiary. Does not change with reassignTokens
     * @return creditToken - token needed to repay the default beneficiary
     * @return debtOwed - debt owed the default beneficiary
     */
    function getDefaultBeneficiaryBasicData()
        external
        view
        returns (uint256 allocation, address creditToken, uint256 debtOwed)
    {
        BeneficiaryData memory b = _defaultBeneficiary();
        return (b.allocation, b.creditToken, 0);
    }

    /**
     * @notice gets the default beneficiary data for credit token and allocation
     * @return allocation - the default allocation of tokens that gets set aside for beneficiary. Does not change with reassignTokens
     * @return creditToken - token needed to repay the beneficiary
     * @return debtOwed - debt owed the beneficiary
     */
    function getBeneficiaryBasicData(address beneficiary)
        external
        view
        returns (uint256 allocation, address creditToken, uint256 debtOwed)
    {
        BeneficiaryData storage b = _beneficiaryData(beneficiary);
        return (b.allocation, b.creditToken, _getDebtOwed(beneficiary));
    }

    /**
     * @notice gets the beneficiary data for a given beneficiary
     * @param beneficiary - the beneficiary to get data for
     * @return - the beneficiary data
     */
    function getBeneficiaryData(address beneficiary) external view returns (BeneficiaryData memory) {
        return _beneficiaryData(beneficiary);
    }

    /**
     * @notice returns the allocation of a benefiary for a given token. Gets adjusted when reassignedTokens is called
     * @param token - the token to get the allocation for
     * @param beneficiary - the beneficiary to get the allocation for
     * @return - the allocation of the beneficiary for the token
     */
    function allocationOf(address token, address beneficiary) external view returns (uint256) {
        return _allocationOf(token, beneficiary);
    }

    /**
     * @notice if a token has been whitelisted for otc swap
     * @param token - the token to check
     * @return - true if the token is whitelisted, false otherwise
     */
    function isTokenWhitelisted(address token) external view returns (bool) {
        return otcState.stableCoinWhitelist[token];
    }

    /**
     * @notice gets the allowed price impact for non stable coin otc swaps
     * @return - the allowed price impact
     */
    function getOTCPriceImpact() external view returns (uint128) {
        return otcState.nonStableCoinPriceImpact;
    }
}
// SPDX-License-Identifier: GPL-3.0
// Copyright: https://github.com/credit-cooperative/Line-Of-Credit-v2/blob/master/COPYRIGHT.md

pragma solidity 0.8.25;

import {ILineOfCredit} from "./lib_Line-Of-Credit-v2_contracts_interfaces_ILineOfCredit.sol";
import {IOracle} from "./lib_Line-Of-Credit-v2_contracts_interfaces_IOracle.sol";
import {LineLib} from "./lib_Line-Of-Credit-v2_contracts_utils_LineLib.sol";
import {FeesLib} from "./lib_Line-Of-Credit-v2_contracts_utils_FeesLib.sol";
import {Denominations} from "./lib_chainlink_contracts_src_v0.8_Denominations.sol";

/**
 * @title   - CreditLib
 * @author  - Credit Cooperative
 * @notice  - Core logic and variables to be reused across all Credit Cooperative LineOfCredit contracts.
 */
library CreditLib {
    event AddCredit(uint256 indexed tokenId, uint256 indexed deposit);

    /// @notice Emitted when Lender withdraws from their initial deposit
    event WithdrawDeposit(uint256 indexed id, uint256 indexed amount);

    /// @notice Emitted when Lender withdraws interest paid by borrower
    event WithdrawProfit(uint256 indexed id, uint256 indexed amount);

    /// @notice Emits amount of interest (denominated in credit token) added to a Borrower's outstanding balance
    event InterestAccrued(uint256 indexed id, uint256 indexed amount);

    // Borrower Events

    /// @notice Emits when Borrower has drawn down an amount (denominated in credit.token) on a credit line
    event Borrow(uint256 indexed id, uint256 indexed amount, address indexed to);

    /// @notice Emits that a Borrower has repaid some amount of interest (denominated in credit.token)
    event RepayInterest(uint256 indexed id, uint256 indexed amount);

    /// @notice Emits that a Borrower has repaid some amount of principal (denominated in credit.token)
    event RepayPrincipal(uint256 indexed id, uint256 indexed amount);

    /// @notice Emits that a Borrower has paid a servicing fee (denominated in credit.token)
    event PayServicingFee(uint256 indexed id, uint256 indexed amount);

    // Errors

    error NoTokenPrice();
    error PositionExists();
    error RepayAmountExceedsDebt(uint256 totalAvailable);
    error InvalidTokenDecimals();
    error PositionIsClosed();
    error NoLiquidity();
    error CloseFailedWithPrincipal();
    error CallerAccessDenied();
    error NotSupported();

    // getOutstandingDebt() is called by updateOutstandingDebt()
    function getOutstandingDebt(ILineOfCredit.Credit storage c, uint256 id, address oracle, uint256 accruedToken)
        internal
        returns (uint256 principal, uint256 interest)
    {
        accrue(c, id, accruedToken);

        int256 price = IOracle(oracle).getLatestAnswer(c.token);

        principal = calculateValue(price, c.principal, c.decimals);
        interest = calculateValue(price, c.interestAccrued, c.decimals);
    }

    /**
     * @notice         - Calculates value of tokens.  Used for calculating the USD value of principal and of interest during getOutstandingDebt()
     * @dev            - Assumes Oracle returns answers in USD with 1e8 decimals
     *                 - If price < 0 then we treat it as 0.
     * @param price    - The Oracle price of the asset. 8 decimals
     * @param amount   - The amount of tokens being valued.
     * @param decimals - Token decimals to remove for USD price
     * @return         - The total USD value of the amount of tokens being valued in 8 decimals
     */
    function calculateValue(int256 price, uint256 amount, uint8 decimals) internal pure returns (uint256) {
        return price <= 0 ? 0 : (amount * uint256(price)) / (1 * 10 ** decimals);
    }

    /**
     * see ILineOfCredit._createCredit
     * @notice called by LineOfCredit._createCredit during every repayment function
     * @param oracle - interset rate contract used by line that will calculate interest owed
     */
    function create(
        uint256 amount,
        uint256 tokenId,
        address token,
        address oracle,
        bool isRestricted,
        uint16 earlyWithdrawalFee,
        uint256 deadline
    ) external returns (ILineOfCredit.Credit memory credit) {
        int256 price = IOracle(oracle).getLatestAnswer(token);
        if (price <= 0) {
            revert NoTokenPrice();
        }

        (bool passed, bytes memory result) = token.call(abi.encodeWithSignature("decimals()"));

        if (!passed || result.length == 0) {
            revert InvalidTokenDecimals();
        }

        uint8 decimals = abi.decode(result, (uint8));

        credit = ILineOfCredit.Credit({
            tokenId: tokenId,
            token: token,
            decimals: decimals,
            deposit: amount,
            principal: 0,
            interestAccrued: 0,
            interestRepaid: 0,
            isOpen: true,
            isRestricted: isRestricted,
            earlyWithdrawalFee: earlyWithdrawalFee,
            deadline: deadline
        });

        emit AddCredit(tokenId, amount);

        return credit;
    }

    /**
     * see ILineOfCredit._repay
     * @notice called by LineOfCredit._repay during every repayment function
     * @dev uses uncheckd math. assumes checks have been done in caller
     * @param credit - The lender position being repaid
     * @param fees - struct containing the different fees set on the lin
     * @param id - tokenId of the credit positiojn
     * @param amount - the amount being repaid
     * @param protocolTreasury - address of the treasury where fees are sent
     */
    function repay(
        ILineOfCredit.Credit storage credit,
        ILineOfCredit.Fees storage fees,
        uint256 id,
        uint256 amount,
        address payer,
        address protocolTreasury
    ) external {
        if (!credit.isOpen) {
            revert PositionIsClosed();
        }
        uint256 servicingFeeAmount = FeesLib._calculateServicingFeeFromAmount(fees, amount);
        uint256 amountLessServicing = amount - servicingFeeAmount;

            if (amountLessServicing > credit.principal + credit.interestAccrued) {
                revert RepayAmountExceedsDebt(credit.principal + credit.interestAccrued);
            }
            if (amountLessServicing <= credit.interestAccrued) {
                credit.interestAccrued -= amountLessServicing;
                credit.interestRepaid += amountLessServicing;
                emit RepayInterest(id, amountLessServicing);
                emit PayServicingFee(id, servicingFeeAmount);
            } else {
                uint256 interest = credit.interestAccrued;
                uint256 principalPayment = amountLessServicing - interest;

                // update individual credit line denominated in token
                credit.principal -= principalPayment;
                credit.interestRepaid += interest;
                credit.interestAccrued = 0;

                emit RepayInterest(id, interest);
                emit RepayPrincipal(id, principalPayment);
                emit PayServicingFee(id, servicingFeeAmount);
            }

        // if we arent using funds from reserves to repay then pull tokens from target
        if (payer != address(0)) {
            // receive tokens from payer
            LineLib.receiveTokenOrETH(credit.token, payer, amount);
        }

        // send servicing fees to protocol treasury
        LineLib.sendOutTokenOrETH(credit.token, protocolTreasury, servicingFeeAmount);
    }

    /**
     * see ILineOfCredit.withdraw
     * @notice called by LineOfCredit.withdraw during every repayment function
     * @dev uses uncheckd math. assumes checks have been done in caller
     * @param credit - The lender position that is being withdrawn from
     * @param tokenId - id of the credit position
     * @param caller - address calling the function
     * @param amount - amount being withdrawn
     */
    function withdraw(ILineOfCredit.Credit storage credit, uint256 tokenId, address caller, uint256 amount, uint256 earlyWithdrawalFee) external {
        if (tokenId != credit.tokenId) {
            revert CallerAccessDenied();
        }

            if (amount > credit.deposit - credit.principal + credit.interestRepaid) {
                revert ILineOfCredit.NoLiquidity();
            }

            if (amount > credit.interestRepaid) {
                uint256 interest = credit.interestRepaid;

                credit.deposit -= (amount - interest);
                credit.interestRepaid = 0;

                // emit events before setting to 0
                emit WithdrawDeposit(tokenId, amount - interest);
                emit WithdrawProfit(tokenId, interest);
            } else {
                credit.interestRepaid -= amount;
                emit WithdrawProfit(tokenId, amount);
            }

        LineLib.sendOutTokenOrETH(credit.token, caller, amount - earlyWithdrawalFee);
    }

    /**
     * see ILineOfCredit._accrue
     * @notice called by LineOfCredit._accrue during every repayment function
     * @dev public to use in `getOutstandingDebt`
     * @param credit - credit struct that we want to accrue interest on
     * @param id - id of the credit position
     * @param accruedToken - token demoninated interest accrued
     */
    function accrue(ILineOfCredit.Credit storage credit, uint256 id, uint256 accruedToken) internal {
        if (!credit.isOpen) {
            return;
        }
            // interest will almost always be less than deposit
            // low risk of overflow unless extremely high interest rate

            // update credit line balance
            credit.interestAccrued += accruedToken;

            emit InterestAccrued(id, accruedToken);
    }
}
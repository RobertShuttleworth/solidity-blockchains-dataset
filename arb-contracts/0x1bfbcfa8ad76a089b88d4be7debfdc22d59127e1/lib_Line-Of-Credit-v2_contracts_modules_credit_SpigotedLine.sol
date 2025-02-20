// SPDX-License-Identifier: GPL-3.0
// Copyright: https://github.com/credit-cooperative/Line-Of-Credit-v2/blob/master/COPYRIGHT.md

pragma solidity 0.8.25;

import {LineOfCredit} from "./lib_Line-Of-Credit-v2_contracts_modules_credit_LineOfCredit.sol";
import {ILineOfCredit} from "./lib_Line-Of-Credit-v2_contracts_interfaces_ILineOfCredit.sol";
import {SpigotedLineLib} from "./lib_Line-Of-Credit-v2_contracts_utils_SpigotedLineLib.sol";
import {ISpigot} from "./lib_Line-Of-Credit-v2_contracts_interfaces_ISpigot.sol";
import {ISpigotedLine} from "./lib_Line-Of-Credit-v2_contracts_interfaces_ISpigotedLine.sol";
import {FeesLib} from "./lib_Line-Of-Credit-v2_contracts_utils_FeesLib.sol";

/**
 * @title  - Credit Cooperative Spigoted Line of Credit
 * @author - Credit Cooperative
 * @notice - Line of Credit contract with additional functionality for integrating with a Spigot and borrower contract collateral.
 * @notice - Allows Admin to repay debt using collateralized cash flows onbehalf of Borrower and Lender(s)
 * @dev    - Inherits LineOfCredit functionality
 */
abstract contract SpigotedLine is ISpigotedLine, LineOfCredit {
    /// @notice see Spigot
    ISpigot public spigot;

    /// @notice - maximum tokens we want to be able to take from spigots if Line is in default
    uint8 constant MAX_SPLIT = 100;

    /**
     * @notice - excess unsold tokens claimed from Spigot to be sold later or excess credit tokens bought from spigot tokens but not yet used to repay debt
     *         - needed because the Line of Credit might have the same token being lent/borrower as being bought/sold so need to separate accounting.
     * @dev    - private variable so other Line modules do not interfer with Spigot functionality
     */
    mapping(address => uint256) private unusedTokens;

    /**
     * @notice - The SpigotedLine is a LineofCredit contract with additional functionality for integrating with a Spigot.
     * @notice - allows Borrower or Lender to repay debt using collateralized cash flows
     * @param oracle_         - address of the oracle contract
     */
    constructor(address oracle_) LineOfCredit(oracle_) {}

    /**
     * @notice  - Internal function used by SecuredLine to initialize the SpigotedLine
     * @param admin_           - address of the admin
     * @param borrower_        - address of the borrower
     * @param recoveryEnabled_ - boolean indicating if recovery functionality is enabled
     * @param spigot_          - address of the Spigot contract
     * @param fees_            - struct of fees (i.e. origination, servicing, swap) for the line
     */
    function _initializeFromFactory(
        address admin_,
        address borrower_,
        bool recoveryEnabled_,
        address spigot_,
        ILineOfCredit.Fees memory fees_
    ) internal virtual {
        spigot = ISpigot(spigot_);

        admin = admin_;
        isServicer[admin_] = true;
        recoveryEnabled = recoveryEnabled_;
        borrower = borrower_;
        fees = fees_;
    }

    /**
     * see LineOfCredit._init and Securedline.init
     * @notice requires this Line is owner of the Escrowed collateral else Line will not init
     */
    function _init() internal virtual override(LineOfCredit) {
        if (spigot.owner() != address(this)) revert BadModule(address(spigot));
    }

    /**
        * @notice - Internal function to get swapTarget address from LineFactory
    */

    function swapTarget() public view returns (address payable) {
        return lineFactory.swapTarget();
    }

    /**
     * @notice - Close a credit position.
     * @dev    - Callable by borrower, servicer, or admin
     * @dev    - closes position by repaying all interest accrued. If there are tokens in unused, they are used to close the position.
     * @param id - id of the credit position to close
     *
     */
    function close(uint256 id) public override {
        _onlyBorrowerOrServicer();
        Credit storage credit = credits[id];
        _accrue(credit, id);

        uint256 totalOwed = credit.interestAccrued + FeesLib._calculateServicingFee(fees, credit.interestAccrued);
        uint256 unusedTokensForClosingPosition = unusedTokens[credit.token];

        if (totalOwed != 0) {
            if (unusedTokensForClosingPosition >= totalOwed) {
                unusedTokens[credit.token] -= totalOwed;
                emit ReservesChanged(credit.token, -int256(unusedTokensForClosingPosition), 1);
                _repay(credit, id, totalOwed, address(0)); // no payer, we already have funds
                _close(credit, id);
            } else {
                unusedTokens[credit.token] = 0;
                totalOwed -= unusedTokensForClosingPosition;
                emit ReservesChanged(credit.token, -int256(unusedTokensForClosingPosition), 1);
                _repay(credit, id, unusedTokensForClosingPosition, address(0)); // no payer, we already have funds
                super.close(id); // borrower will need to repay the rest
            }
        } else {
            super.close(id);
        }
    }

    /**
     * @notice  - Claims spigot tokens from the Spigot, trades them for credit tokens via a Dex aggregator (Ox protocol) and uses the bought credit tokens to repay debt.
     *          - see SpigotedLine._claimAndTrade and SpigotedLineLib.claimAndTrade for more details on Spigot and trading logic
     *          - see LineOfCredit._repay() for more details on repayment logic
     * @dev     - does not trade asset if claimToken = credit.token
     * @dev     - callable by `admin`
     * @param claimToken       - The token escrowed by Spigot to claim and use to repay debt
     * @param zeroExTradeData  - data generated by the 0x dex API to trade `claimToken` against their exchange contract
     * @return newTokens       - amount of credit tokens claimed or bought during call
     */
    function claimAndRepay(address claimToken, bytes calldata zeroExTradeData) external returns (uint256) {
        _whileBorrowing();
        uint256 id = ids[0];
        Credit storage credit = credits[id];

        // only admin can call this function when _claimAndTrade is called with claimToken != credit.token
        if (msg.sender != admin && claimToken != credit.token) {
            revert CallerAccessDenied();
        }

        // servicer can call this function when _claimAndTrade is called with claimToken == credit.token
        if (!isServicer[msg.sender] && msg.sender != admin) {
            revert CallerAccessDenied();
        }
        _accrue(credit, id);

        uint256 newTokens = _claimAndTrade(claimToken, credit.token, zeroExTradeData);
        uint256 repaid = newTokens + unusedTokens[credit.token];
        uint256 debt = credit.interestAccrued + credit.principal;

        debt += FeesLib._calculateServicingFee(fees, debt);

        // cap payment to debt value plus servicing fee
        if (repaid > debt) {
            repaid = debt;
        }

        // update reserves based on usage
        uint256 diff;
        if (repaid > newTokens) {
            // if using `unusedTokens` to repay line, reduce reserves
            diff = repaid - newTokens;
            emit ReservesChanged(credit.token, -int256(diff), 1);
            unusedTokens[credit.token] -= diff;
        } else {
            // else high spigot tokens and bought more credit tokens than owed, fill reserves
            diff = newTokens - repaid;
            emit ReservesChanged(credit.token, int256(diff), 1);
            unusedTokens[credit.token] += diff;
        }

        _repay(credit, id, repaid, address(0)); // no payer, we already have funds

        emit SpigotPayment(claimToken, repaid);

        return newTokens;
    }

    /**
     * @notice - Directly repays a Lender using unused tokens already held by Line with no trading
     * @dev    - callable by `borrower` or first lender in repayment queue
     * @param amount       - amount of unused tokens to use to repay Lender
     */
    function useAndRepay(uint256 amount) external {
        _whileBorrowing();
        uint256 id = ids[0];
        Credit storage credit = credits[id];
        address lender = tokenContract.ownerOf(credit.tokenId);

        if (msg.sender != borrower && msg.sender != lender && !isServicer[msg.sender]) {
            revert CallerAccessDenied();
        }

        if (amount > unusedTokens[credit.token]) {
            revert ReservesOverdrawn(credit.token, unusedTokens[credit.token]);
        }

        _accrue(credit, id);

        uint256 servicingFeeAmount = FeesLib._calculateServicingFeeFromAmount(fees, amount);

        // if amount is greater than total owed, adjust amount to be total owed
        if (amount > credit.principal + credit.interestAccrued + servicingFeeAmount) {
            servicingFeeAmount = FeesLib._calculateServicingFee(fees, credit.principal + credit.interestAccrued);
            amount = credit.principal + credit.interestAccrued + servicingFeeAmount;
        }

        // reduce reserves before _repay calls token to prevent reentrancy
        unusedTokens[credit.token] -= amount;
        emit ReservesChanged(credit.token, -int256(amount), 0);
        _repay(credit, id, amount, address(0)); // no payer, we already have funds

        emit SpigotPayment(credit.token, amount);
    }

    /**
     *
     * @notice - allows borrower to trade spigot tokens to credit tokens at a favorable price without repaying debt
     *         - sends all bought tokens to `unused` to be repaid later
     *         - see SpigotedLine._claimAndTrade and SpigotedLineLib.claimAndTrade for more details
     * @dev    - ensures first token in repayment queue is being bought
     * @dev    - callable by `admin`
     * @param claimToken      - The spigot token escrowed in the Spigot to sell in trade
     * @param zeroExTradeData - 0x API data to use in trade to sell `claimToken` for `credits[ids[0]]`
     * @return tokensBought   - amount of credit tokens bought
     */
    function claimAndTrade(address claimToken, bytes calldata zeroExTradeData) external returns (uint256) {
        _onlyAdmin();
        address targetToken = credits[ids[0]].token;
        uint256 newTokens = _claimAndTrade(claimToken, targetToken, zeroExTradeData);

        // add bought tokens to unused balance
        unusedTokens[targetToken] += newTokens;
        emit ReservesChanged(targetToken, int256(newTokens), 1);

        return newTokens;
    }

    /**
     * @notice  - Claims spigot tokens escrowed in Spigot and trades them for credit tokens.
     *          - MUST trade all available claim tokens to target credit token.
     *          - Excess credit tokens not used to repay dent are stored in `unused`
     * @dev     - priviliged internal function
     * @param claimToken - The spigot token escrowed in the Spigot to sell in trade
     * @param targetToken - The credit token that needs to be bought in order to pat down debt. Always `credits[ids[0]].token`
     * @param zeroExTradeData - 0x API data to use in trade to sell `claimToken` for target
     * @return - amount of target tokens bought
     */
    function _claimAndTrade(address claimToken, address targetToken, bytes calldata zeroExTradeData)
        internal
        returns (uint256)
    {
        // can't trade into same token. causes double count for unused tokens
        if (claimToken == targetToken) {
            return spigot.claimOwnerTokens(claimToken);
        } else {
            // trade spigot token for debt obligation
            ISpigotedLine.ClaimAndTradeParams memory params = ISpigotedLine.ClaimAndTradeParams({
                claimToken: claimToken,
                targetToken: targetToken,
                swapTarget: lineFactory.swapTarget(),
                spigot: address(spigot),
                unused: unusedTokens[claimToken],
                swapFee: fees.swapFee,
                protocolTreasury: lineFactory.protocolTreasury(),
                zeroExTradeData: zeroExTradeData
            });
            (uint256 tokensBought, uint256 totalUnused) = SpigotedLineLib.claimAndTrade(params);

            // we dont use spigot tokens after this so can store now
            /// @dev ReservesChanged event for claim token is emitted in SpigotedLineLib.claimAndTrade
            unusedTokens[claimToken] = totalUnused;

            // the target tokens purchased
            return tokensBought;
        }
    }

    /**
     * @notice   - sends unused tokens to borrower if REPAID or admin if LIQUIDATABLE or INSOLVENT
     *           -  does not send tokens out if line is ACTIVE
     * @dev      - callable by `borrower` or `admin`
     * @param to           - address to send swept tokens to
     * @param token        - address of token to sweep
     * @param amount       - amount of reserve tokens to withdraw/liquidate
     */
    function sweep(address to, address token, uint256 amount) external nonReentrant {
        _onlyBorrowerOrServicer();
        uint256 swept = SpigotedLineLib.sweep(
            to, token, amount, unusedTokens[token], _updateStatus(_healthcheck()), borrower, admin
        );

        if (swept != 0) {
            unusedTokens[token] -= swept;
            emit ReservesChanged(token, -int256(swept), 1);
        }
    }

    /**
     * @notice - Looksup `unusedTokens` + spigot.getOwnerTokens` for how many tokens admin must sell in claimAndTrade/Repay
     * @param token      - address for an ERC20 earned
     * @return amount    - amount of unused + claimable spigot tokens available to trade for credit tokens or credit tokens availble to repay debt with
     */
    function tradeable(address token) external view returns (uint256) {
        return unusedTokens[token] + spigot.getOwnerTokens(token);
    }

    /**
     * @notice - getter for `unusedTokens` mapping which is a private var
     * @param token      - address for an ERC20
     * @return amount    - amount of spigot tokens available to trade for credit tokens or credit tokens availble to repay debt with
     */
    function unused(address token) external view returns (uint256) {
        return unusedTokens[token];
    }

    // allow claiming/trading in ETH
    receive() external payable {}
}
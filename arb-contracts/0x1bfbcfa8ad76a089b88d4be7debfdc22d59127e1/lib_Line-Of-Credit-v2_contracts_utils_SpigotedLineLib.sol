// SPDX-License-Identifier: GPL-3.0
// Copyright: https://github.com/credit-cooperative/Line-Of-Credit-v2/blob/master/COPYRIGHT.md

pragma solidity 0.8.25;

import {ISpigot} from "./lib_Line-Of-Credit-v2_contracts_interfaces_ISpigot.sol";
import {ISpigotedLine} from "./lib_Line-Of-Credit-v2_contracts_interfaces_ISpigotedLine.sol";
import {LineLib} from "./lib_Line-Of-Credit-v2_contracts_utils_LineLib.sol";
import {IERC20} from "./lib_openzeppelin-contracts_contracts_token_ERC20_IERC20.sol";
import {SafeERC20} from "./lib_openzeppelin-contracts_contracts_token_ERC20_utils_SafeERC20.sol";

/**
 * @title   - SpigotedLineLib
 * @author  - Credit Cooperative
 * @notice  - Core logic used SpigotedLine contract for trading tokens in Spigot and sweeping tokens outside of Spigot.
 */
library SpigotedLineLib {
    using SafeERC20 for IERC20;
    /// @notice - maximum tokens we want to be able to take from spigots if Line is in default

    uint8 constant MAX_SPLIT = 100;

    error NoSpigot();
    error TradeFailed();
    error BadTradingPair();
    error CallerAccessDenied();
    error NotInsolvent(address module);
    error ReservesOverdrawn(address token, uint256 amountAvailable);

    event TradeSpigotTokens(
        address indexed spigotToken,
        uint256 spigotTokenAmount,
        address indexed debtToken,
        uint256 indexed debtTokensBought
    );

    // 0 for spigot token, 1 for credit token
    event ReservesChanged(address indexed token, int256 indexed diff, uint256 tokenType);

    event RemoveSpigot(address indexed borrowerContract);

    /**
     * @dev                 - priviliged internal function!
     * @notice              - Allows spigot tokens in 'escrowed' to be traded for credit tokens that aren't yet used to repay debt.
     *                         - The newly exchanged credit tokens are held in 'unusedTokens' ready for a Lender to withdraw using useAndRepay
     *                         - This feature allows a Borrower to take advantage of an increase in the value of the spigot token compared
     *                         - to the credit token and to in effect use less spigot tokens to be later used to repay the same amount of debt.
     * @dev                 - MUST trade all available claimTokens (unused + claimed) to targetTokens
     * @param params    -
     */
    function claimAndTrade(ISpigotedLine.ClaimAndTradeParams calldata params) external returns (uint256, uint256) {
        // snapshot token balances now to diff after trade executes
        uint256 oldClaimTokens = LineLib.getBalance(params.claimToken);

        uint256 oldTargetTokens = LineLib.getBalance(params.targetToken);

        // @dev claim has to be called after we get balance
        // reverts if there are no tokens to claim
        uint256 claimed = ISpigot(params.spigot).claimOwnerTokens(params.claimToken);
        trade(claimed + params.unused, params.claimToken, params.swapTarget, params.zeroExTradeData);

        // underflow revert ensures we have more tokens than we started with
        uint256 tokensBought = LineLib.getBalance(params.targetToken) - oldTargetTokens;
        if (tokensBought == 0) {
            revert TradeFailed();
        } // ensure tokens bought

        uint256 newClaimTokens = LineLib.getBalance(params.claimToken);

        // ideally we could use oracle here to calculate # of tokens to receive
        // but sellToken might not have oracle. buyToken must have oracle

        emit TradeSpigotTokens(params.claimToken, claimed, params.targetToken, tokensBought);

        uint256 diff;
        // used reserve tokens to repay debt
        if (oldClaimTokens > newClaimTokens) {

                diff = oldClaimTokens - newClaimTokens;

                emit ReservesChanged(params.claimToken, -int256(diff), 0);

                // used more tokens than we had in reserves.
                // prevent borrower from pulling idle lender funds to repay other lenders
                if (diff > params.unused) revert ReservesOverdrawn(params.claimToken, params.unused);
                // reduce reserves by consumed amount
                else return (tokensBought, params.unused - diff);

        } else {

                // `unused` unlikely to overflow
                // excess tokens in trade. store in reserves
                diff = newClaimTokens - oldClaimTokens;

                emit ReservesChanged(params.claimToken, int256(diff), 0);

                return (tokensBought, params.unused + diff);

        }
    }

    /**
     * @dev                     - priviliged internal function!
     * @notice                  - dumb func that executes arbitry code against a target contract
     * @param amount            - amount of spigot tokens to sell
     * @param sellToken         - spigot token being sold
     * @param swapTarget        - exchange aggregator to trade against
     * @param zeroExTradeData   - Trade data to execute against exchange for target token/amount
     */
    function trade(uint256 amount, address sellToken, address payable swapTarget, bytes calldata zeroExTradeData)
        public
    {
        IERC20(sellToken).forceApprove(swapTarget, amount);
        (bool success,) = swapTarget.call(zeroExTradeData);
        if (!success) {
            revert TradeFailed();
        }
        IERC20(sellToken).forceApprove(swapTarget, 0);
    }

    /**
     * @notice -  Sends unused tokens in the Line to the Borrower after the loan has been repaid.
     *               - Can be used after borrower has repaid the loan to withdraw any unused tokens from the Line
     *               -  In case of a Borrower default (loan status = liquidatable), this can be used as fallback mechanism to withdraw all the tokens and send them to the Admin
     *               -  Does not transfer anything if line is healthy
     *               - `admin` can only withdraw unused tokens to the `borrower`
     *               - `borrower` can withdraw unused tokens to any address
     * @dev    - callable by `borrower` or `admin`
     * @param to - address to sweep tokens to
     * @param token - token being swept
     * @param amount - amount being swept
     * @param available - unused tokens in LoC
     * @param status - status of the line
     * @param borrower - the borrower
     * @param admin - address of admin
     * @return - amount that is swept
     */
    function sweep(
        address to,
        address token,
        uint256 amount,
        uint256 available,
        LineLib.STATUS status,
        address borrower,
        address admin
    ) external returns (uint256) {
        if (available == 0) {
            return 0;
        }
        if (amount == 0) {
            // use all tokens if no amount specified specified
            amount = available;
        } else {
            if (amount > available) {
                revert ReservesOverdrawn(token, available);
            }
        }

        if (status == LineLib.STATUS.REPAID && (msg.sender == borrower || to == borrower)) {
            LineLib.sendOutTokenOrETH(token, to, amount);
            return amount;
        }

        if ((status == LineLib.STATUS.LIQUIDATABLE || status == LineLib.STATUS.INSOLVENT) && msg.sender == admin) {
            LineLib.sendOutTokenOrETH(token, to, amount);
            return amount;
        }

        revert CallerAccessDenied();
    }
}
// SPDX-License-Identifier: GPL-3.0
// Copyright: https://github.com/credit-cooperative/Line-Of-Credit-v2/blob/master/COPYRIGHT.md

pragma solidity 0.8.25;

import {LineLib} from "./lib_Line-Of-Credit-v2_contracts_utils_LineLib.sol";
import {EscrowedLine} from "./lib_Line-Of-Credit-v2_contracts_modules_credit_EscrowedLine.sol";
import {SpigotedLine} from "./lib_Line-Of-Credit-v2_contracts_modules_credit_SpigotedLine.sol";
import {LineOfCredit} from "./lib_Line-Of-Credit-v2_contracts_modules_credit_LineOfCredit.sol";
import {ILineOfCredit} from "./lib_Line-Of-Credit-v2_contracts_interfaces_ILineOfCredit.sol";
import {ISecuredLine} from "./lib_Line-Of-Credit-v2_contracts_interfaces_ISecuredLine.sol";
import {IEscrow} from "./lib_Line-Of-Credit-v2_contracts_interfaces_IEscrow.sol";
import {ICreditPositionToken} from "./lib_Line-Of-Credit-v2_contracts_interfaces_ICreditPositionToken.sol";
import {ILineFactory} from "./lib_Line-Of-Credit-v2_contracts_interfaces_ILineFactory.sol";
import {MutualConsent} from "./lib_Line-Of-Credit-v2_contracts_utils_MutualConsent.sol";

/**
 * @title  - Secured Line of Credit
 * @author - Credit Cooperative
 * @notice - The SecuredLine combines both collateral modules (SpigotedLine + EscrowedLine) with core lending functionality from LineOfCredit to create a fully secured lending facility backed by tokens accrued via Spigot or tokens via Escrow.
 * @dev    - modifies _liquidate(), _healthcheck(), _init(), and _declareInsolvent() functionality
 */
contract SecuredLine is SpigotedLine, EscrowedLine, ISecuredLine {
    bool private initializedFromFactory = false;

    constructor(address oracle_) SpigotedLine(oracle_) {
        lineFactory = ILineFactory(msg.sender);
    }

    /**
     * @notice  - Initialize SecuredLine contract
     * @dev     - SecuredLine is deployed and initialized from LineFactory
     * @param admin_           - address of the admin
     * @param borrower_        - address of the borrower
     * @param recoveryEnabled_ - boolean indicating if recovery functionality is enabled
     * @param spigot_          - address of the Spigot contract
     * @param escrow_          - address of the Escrow contract
     * @param creditPositionToken_ - address of the CreditPositionToken contract
     * @param fees_            - struct of fees (i.e. origination, servicing, swap) for the line
     */
    function initializeFromFactory(
        address admin_,
        address borrower_,
        bool recoveryEnabled_,
        address spigot_,
        address escrow_,
        address creditPositionToken_,
        ILineOfCredit.Fees memory fees_
    ) external {
        if (initializedFromFactory) {
            revert AlreadyInitialized();
        }

        if (msg.sender != address(lineFactory)) {
            revert CallerAccessDenied();
        }

        initializedFromFactory = true;

        // Call the initialization function of SpigotedLine parent
        _initializeFromFactory(admin_, borrower_, recoveryEnabled_, spigot_, fees_);

        // Set the escrow contract from EscrowedLine
        escrow = IEscrow(escrow_);
        tokenContract = ICreditPositionToken(creditPositionToken_);

        emit DeployLine(msg.sender, address(oracle), admin_, borrower_, recoveryEnabled_);
    }

    /**
     * @dev requires both Spigot and Escrow to pass _init to succeed
     */
    function _init() internal virtual override(SpigotedLine, EscrowedLine) {
        SpigotedLine._init();
        EscrowedLine._init();
    }

    /**
     * @notice - Set line's status to ABORTED
     * @notice - Once line's status is ABORTED, it cannot be reactivated (i.e. set to ACTIVE)
     * @notice - Once status is ABORTED, tokens in escrow, line, and spigot, as well as borrower contracts owned by the spigot,
     *  can be transferred by the admin for emergency response
     * @dev    - only callable by the admin and borrower
     */
    function abort() external mutualConsent(admin, borrower) {
        _isRecoverable();
        _updateStatus(LineLib.STATUS.ABORTED);
    }

    function _healthcheck() internal override(EscrowedLine, LineOfCredit) returns (LineLib.STATUS) {
        // check core (also cheap & internal) covenants before checking collateral conditions
        LineLib.STATUS s = LineOfCredit._healthcheck();
        if (s != LineLib.STATUS.ACTIVE) {
            // return early if non-default answer
            return s;
        }

        // check collateral ratio and return ACTIVE
        return EscrowedLine._healthcheck();
    }

    /**
     * @notice - clears any credit proposals that are currently in the line
     * @dev    - only callable by the spigot or escrow addresses
     */
    function clearProposals() external {
        if (msg.sender != address(spigot) && msg.sender != address(escrow)) {
            revert CallerAccessDenied();
        }
        _clearProposals();
    }

    /**
     * @notice - activates the line by setting status to active
     * @dev    - only callable by the spigot or escrow addresses
     */
    function activateLine() external {
        if (msg.sender != address(spigot) && msg.sender != address(escrow)) {
            revert CallerAccessDenied();
        }
        _updateStatus(LineLib.STATUS.ACTIVE);
    }

    /**
     * @notice - increments the nonce of the line if any state changes are made by the escrow or spigot
     * @dev    - only callable by the spigot or escrow addresses
     */
    function incrementNonce() external {
        if (msg.sender != address(spigot) && msg.sender != address(escrow)) {
            revert CallerAccessDenied();
        }
        nonce++;
    }

    /**
     * @notice - revoke consent for a given proposal
     * @dev    - only callable by token holder or borrower
     * @param tokenId               - the token id of the proposal to revoke consent for (used for LineOfCredit.refinanceCredit)
     * @param _reconstructedMsgData - the reconstructed message data from the proposal
     */
    function revokeConsent(uint256 tokenId, bytes calldata _reconstructedMsgData)
        public
        override(MutualConsent, ISecuredLine)
    {
        _onlyTokenHolderOrBorrower(tokenId);
        super.revokeConsent(tokenId, _reconstructedMsgData);
        if (tokenId != 0) {
            if (tokenContract.ownerOf(tokenId) == msg.sender) {
                tokenContract.closeProposal(tokenId);
            }
        }
    }

    /**
     * @notice - allows the line to change the allowed price impact for OTC trades on both the spigot and escrow
     * @dev    - only callable by the admin and borrower via mutual consent
     * @param allowedPriceImpact - the new price impact that is allowed
     */
    function updateAllowedOTCPriceImpact(uint128 allowedPriceImpact) external mutualConsent(admin, borrower) {
        escrow.updateAllowedOTCPriceImpact(allowedPriceImpact);
        spigot.updateAllowedOTCPriceImpact(allowedPriceImpact);
    }
}
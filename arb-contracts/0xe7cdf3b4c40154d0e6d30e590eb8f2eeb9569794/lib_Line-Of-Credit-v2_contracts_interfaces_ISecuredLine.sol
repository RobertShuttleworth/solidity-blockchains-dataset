// SPDX-License-Identifier: GPL-3.0
// Copyright: https://github.com/credit-cooperative/Line-Of-Credit-v2/blob/master/COPYRIGHT.md

pragma solidity ^0.8.25;

import {IEscrowedLine} from "./lib_Line-Of-Credit-v2_contracts_interfaces_IEscrowedLine.sol";
import {ISpigotedLine} from "./lib_Line-Of-Credit-v2_contracts_interfaces_ISpigotedLine.sol";

interface ISecuredLine is IEscrowedLine, ISpigotedLine {
    // Errors
    error DebtOwed();
    error CannotAmendLine();

    // Events
    event RecoveredEscrow(address indexed to, uint256 amount, address token);

    // Recovery Functions
    function abort() external;

    // SecuredLine management functions
    function clearProposals() external;
    function activateLine() external;
    function incrementNonce() external;
    function revokeConsent(uint256 tokenId, bytes calldata _reconstructedMsgData) external;
    function updateAllowedOTCPriceImpact(uint128 allowedPriceImpact) external;
}
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

// Inheritance
import "./contracts_core_AMM_Ticket.sol";

contract TicketMastercopy is Ticket {
    constructor() {
        // Freeze mastercopy on deployment so it can never be initialized with real arguments
        initialized = true;
    }
}
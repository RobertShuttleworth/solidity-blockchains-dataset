// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import "./contracts_SharedTypes.sol";

/**
 * @dev IGigabitEscrowStatistics interface
 *
 * This interface defines the functions for interacting with the statistics contract.
 */
interface IGigabitEscrowStatistics {

    // Struct to hold the user statistics
    // note: uint16 (2 bytes) x 12 = 24 bytes, and uint32 (4 bytes) x 2 = 8 bytes, for a total of 32 bytes
    //       which fits perfectly into one storage slot
    struct UserStatistics {
        uint16 totalOrdersInitiated;           // Total orders initiated as a customer
        uint16 totalOrdersReceived;            // Total orders received as a worker
        uint16 totalOrdersInitiatedSuccessful; // Total successful orders initiated as a customer
        uint16 totalOrdersReceivedSuccessful;  // Total successful orders received as a worker
        uint16 timesAsReferrer;                // Times this user has been a referrer
        uint16 timesAsAffiliate;               // Times this user has been an affiliate
        uint16 faultsReceivedAsCustomer;       // Faults recorded against this user as a customer
        uint16 faultsReceivedAsWorker;         // Faults recorded against this user as a worker
        uint16 disputesInitiated;              // Disputes initiated by this user
        uint16 disputesReceived;               // Disputes received by this user
        uint16 reportsInitiated;               // Reports initiated by this user
        uint16 reportsReceived;                // Reports received by this user
        uint32 totalAmountEarned;              // Total amount earned by this user (as worker, affiliate, or referrer)
        uint32 totalAmountSpent;               // Total amount spent by this user (as customer), less any refunds
    }

    // Struct to hold the financial statistics
    // note: Each uint32 (4 bytes) x 8 = 32 bytes, which fits perfectly into one storage slot
    struct FinancialStatistics {
        uint32 spentByCustomers;        // amount spent by customers, less any refunds
        uint32 collectedByWorkers;      // amount earned by workers
        uint32 collectedByAffiliates;   // amount earned by affiliates
        uint32 collectedByReferrers;    // amount earned by referrals
        uint32 collectedByArbiters;     // amount earned by arbiters
        uint32 collectedByCompanyTotal; // amount earned by the company
        uint32 collectedServiceFees;    // service fees collected
        uint32 collectedPlatformFees;   // platform fees collected
    }

    // Struct to hold the statistics for each work status
    // note: uint32 (4 bytes) x 8 = 32 bytes, which fits perfectly into one storage slot
    struct StatusStatistics {
        uint32 awaitingReqs; // Orders currently in the 'AWAITING_REQS' status
        uint32 inQueue;      // Orders currently in the 'IN_QUEUE' status
        uint32 inProgress;   // Orders currently in the 'IN_PROGRESS' status
        uint32 inReview;     // Orders currently in the 'IN_REVIEW' status
        uint32 inDispute;    // Orders currently in the 'IN_DISPUTE' status
        uint32 completed;    // Orders currently in the 'COMPLETED' status
        uint32 settled;      // Orders currently in the 'SETTLED' status
        uint32 canceled;     // Orders currently in the 'CANCELED' status
    }

    function owner() external view returns (address);
    function report(address _reporter, address _reported) external;
    function orderInitiated(address _customer, address _worker) external;
    function updateStatus(uint8 _fromStatus, uint8 _toStatus) external;
    function packedUserStatistics(address _user) external view returns (uint256);
    function addManagerToWhitelist(address _manager) external;
    function isManager(address _address) external view returns (bool);
    function getUserStatistics(address _user) external view returns (UserStatistics memory);
    function getFinancialStatistics() external view returns (FinancialStatistics memory);
    function getStatusStatistics() external view returns (StatusStatistics memory);
    function incrementFaultsReceivedAsWorker(address _worker) external;
    function incrementFaultsReceivedAsCustomer(address _customer) external;
}
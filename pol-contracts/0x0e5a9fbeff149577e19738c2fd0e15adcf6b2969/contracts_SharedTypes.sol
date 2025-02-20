// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

library SharedTypes {
    
    enum WorkStatus {
        NONE,          // 0
        IN_QUEUE,      // 1
        IN_PROGRESS,   // 2
        IN_REVIEW,     // 3
        IN_DISPUTE,    // 4
        COMPLETED,     // 5
        SETTLED,       // 6
        CANCELED,      // 7
        TERMINATED     // 8
    }

    enum DisputeRuling {
        NOT_APPLICABLE,     // 0
        AWAITING_JUDGMENT,  // 1
        WORKER_AT_FAULT,    // 2
        CUSTOMER_AT_FAULT,  // 3
        COMPROMISE          // 4
    }
    
    /**
     *   Mapping of addresses, uint256s, uint64s, uint8s, and strings for this implementation:
     *
     *       _addresses = [0 = stableToken,
     *                     1 = customer,
     *                     2 = worker,
     *                     3 = affiliate (can be 0x address),
     *                     4 = referrer (can be 0x address)]
     *
     *       _uint256s  = [0 = amountDue,
     *                     1 = serviceFee (can be 0)]
     *
     *       _uint64s   = [0 = startByDate]
     *
     *       _uint8s    = [0 = companyPercentageCut
     *                     1 = daysToComplete,
     *                     2 = revisionRequestsLeft,
     *                     3 = extensionRequestsLeft,
     *                     4 = affiliatePercentageCut (can be 0),
     *                     5 = referrerPercentageCut (can be 0)]
     *
     *       _strings   = [0 = orderId]
     *
     *       _bools     = [0 = devMode]
     */
    struct EscrowParams {
        address[] addresses;
        uint256[] uint256s;
        uint64[] uint64s;
        uint8[] uint8s;
        string[] strings;
        bool[] bools;
    }

    struct WorkStatusUpdate {
        uint256 timestamp;
        WorkStatus workStatus;
    }

    struct DisputeRulingUpdate {
        uint256 timestamp;
        DisputeRuling disputeRuling;
    }
}
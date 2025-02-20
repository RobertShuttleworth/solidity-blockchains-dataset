// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import "./contracts_SharedTypes.sol";

interface IGigabitEscrowOrder {
    
    function __init__(SharedTypes.EscrowParams calldata) external;

    function owner() external view returns (address);
    function manager() external view returns (address);
    function stableToken() external view returns (address);
    function worker() external view returns (address);
    function customer() external view returns (address);
    function isImplementation() external view returns (bool);
    function workerReported() external view returns (bool);
    function customerReported() external view returns (bool);

    function amountDue() external view returns (uint256);
    function queuedAt() external view returns (uint64);
    function startedAt() external view returns (uint64);
    function closedAt() external view returns (uint64);
    function emergencyWithdrawProposalAt() external view returns (uint64);

    function daysToComplete() external view returns (uint8);
    function revisionRequestsLeft() external view returns (uint8);
    function extensionRequestsLeft() external view returns (uint8);
    function extensionRequestDays() external view returns (uint8);
    function companyPercentageCut() external view returns (uint8);

    function workStatusUpdates(
        uint256 index
    ) external view returns (SharedTypes.WorkStatusUpdate memory);
    function disputeRulingUpdates(
        uint256 index
    ) external view returns (SharedTypes.DisputeRulingUpdate memory);

    function workStatus() external view returns (SharedTypes.WorkStatus);
    function disputeRuling() external view returns (SharedTypes.DisputeRuling);
    function getBalanceDeficit() external view returns (uint256);

    function signalInProgress() external;
    function signalInReview() external;
    function requestExtension(uint8 extraDays) external;
    function giftRevision(uint8 revisionGiftCount) external;
    function cancelDueToWorkerQuitting() external;
    function completeDueToCustomerTimeout() external;
    function acceptExtensionRequest() external;
    function denyExtensionRequest() external;
    function signalAcceptanceOfWork() external;
    function requestRevision() external;
    function disputeDeliverables() external;
    function disputeReportedBehavior() external;
    function cancelDueToNeglect() external;
    function cancelDueToNonPayment() external;
    function refundPaymentAfterOrderIsCanceled() external;
    function resolveDisputeFavoringCustomer() external;
    function resolveDisputeFavoringWorker() external;
    function resolveDisputeAsCompromise(uint8 percentageToWorker) external;
    function recoverOrphanedEther() external;
    function recoverOrphanedTokens(address, uint256) external;
    function proposeEmergencyWithdraw() external;
    function emergencyWithdraw() external;
    function isPaid() external view returns (bool);
    function setAsImplementation() external;
}
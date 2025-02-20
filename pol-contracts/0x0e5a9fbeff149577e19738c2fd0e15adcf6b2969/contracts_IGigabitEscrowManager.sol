// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

interface IGigabitEscrowManager {
    struct Statistics {
        uint64 awaitingReqs;
        uint64 inQueue;
        uint64 inProgress;
        uint64 inReview;
        uint64 inRevision;
        uint64 inDispute;
        uint64 completed;
        uint64 settled;
        uint64 canceled;
    }

    function owner() external view returns (address);
    function implementation() external view returns (address);
    function feeRecipient() external view returns (address);
    function customerTimeoutDays() external view returns (uint8);
    function maxCompanyPercentageCut() external view returns (uint8);
    function maxDaysToComplete() external view returns (uint8);
    function maxRevisions() external view returns (uint8);
    function maxExtensions() external view returns (uint8);
    function emergencyPause() external view returns (bool);

    function registerStableToken(address) external;
    function setFeeRecipient(address) external;
    function createEscrow(
        address[] calldata addresses,
        uint256[] calldata uint256s,
        uint64[] calldata uint64s,
        uint8[] calldata uint8s,
        string[] calldata strings,
        bytes32[] calldata bools
    ) external;
    function updateStatusStatistics(uint8, uint8) external;
    function getStatistics() external view returns (Statistics memory);
    function isRegisteredStableToken(address) external view returns (bool);
    function getEscrowByOrderId(string memory orderId) external view returns (address escrow);
    function getPredictedEscrowByOrderId(string memory orderId) external view returns (address escrow);
    function getOrderIdByEscrow(address escrow) external view returns (string memory orderId);
    function setImplementation(address) external;
    function setCustomerTimeoutDays(uint8) external;
    function setMaxCompanyPercentageCut(uint8) external;
    function setMaxWorkDays(uint8) external;
    function setMaxRevisions(uint8) external;
    function setMaxExtensions(uint8) external;
    function increaseWorkerFaultCount(address worker) external;
    function increaseCustomerFaultCount(address customer) external;
    function reportInOrder(address reporter, address reported, string memory orderId) external;
    function engageEmergencyPause() external;
    function disengageEmergencyPause() external;
    function isValidTransition(uint8 _from, uint8 _to) external view returns (bool);
}
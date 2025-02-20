// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

/// @dev BridgeErrors defines the errors reported by the bridge contract.
/// @custom:security-contact security@fantom.foundation
interface BridgeErrors {
    // deposit
    error InvalidImplicitDeposit(uint256 amount);
    error InvalidRecipient(address recipient, address sender);
    error DepositBelowLimit(uint256 expected, uint256 received);
    error DepositAboveLimit(uint256 expected, uint256 received);
    error FeeChanged(uint256 expected, uint256 received);

    // balance control
    error BalanceBelowLimit(uint256 limit, uint256 balance);
    error BalanceOverLimit(uint256 limit, uint256 balance);
    error DrainFailed(address target, uint256 amount);

    // batch processing
    error InvalidBatchSequence(uint256 lastID, uint256 currentID);
    error InsufficientLiquidity(uint256 available, uint256 needed);
    error SignatureDeficit(uint256 threshold, uint256 received);
    error InvalidDepositSequence(uint256 lastID, uint256 receivedID);
    error InvalidDepositSum(uint256 expected, uint256 received);
    error DepositNotFound(uint256 depositID);
    error InvalidClaimRequests(address expectedSender);
    error DepositSettlementFailed(address recipient, uint256 amount);

    // config
    error InvalidSignatureThreshold();
    error InvalidMinDepositToFee(uint256 minDeposit, uint256 fee);
    error InvalidMaxDepositToMinDeposit(uint256 maxDeposit, uint256 minDeposit);
    error InvalidDrainAddress();
}
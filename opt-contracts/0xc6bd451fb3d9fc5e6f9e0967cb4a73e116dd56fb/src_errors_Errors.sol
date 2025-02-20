// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

/// @notice Error for zero value input
error InvalidZeroInput();

/// @notice Error for invalid fee recipient (zero address)
error InvalidFeeRecipient();

/// @notice Error for length mismatch between arrays
error LengthMisMatch();

/// @notice Error when address tries to claim more than once
error AlreadyClaimed();

/// @notice Error when signature deadline is expired
error ExceedsDeadline();

// @notice Error when signature threshold is not met
error NotEnoughSignatures();

// @notice Error when not authorized
error NotAuthorized();

/// @notice Error for invalid signature
error InvalidSignature();

/// @notice Error for exceeding epoch limit
error ExceedEpochLimit();

/// @notice Error for exceeding user epoch limit
error ExceedUserEpochLimit();

error InvalidNonce();
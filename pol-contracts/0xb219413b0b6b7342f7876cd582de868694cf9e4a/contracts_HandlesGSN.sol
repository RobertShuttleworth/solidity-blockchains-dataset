// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import "./lib_OpenZeppelin_GSN_GSNRecipient.sol";

abstract contract HandlesGSN is GSNRecipient {
    /**
     * @dev Inheriting from GSNRecipient requires us to implement this function.
     *
     * We can add logic that will execute during a relayed call here
     */
    function acceptRelayedCall(
        address, // relay,
        address, // from,
        bytes calldata, // encodedFunction,
        uint256, // transactionFee,
        uint256, // gasPrice,
        uint256, // gasLimit,
        uint256, // nonce,
        bytes calldata, // approvalData,
        uint256 // maxPossibleCharge
    ) external pure override returns (uint256, bytes memory) {
        // Accept all relayed calls for now
        return _approveRelayedCall();
    }

    /**
     * @dev Inheriting from GSNRecipient requires us to implement this function.
     *
     * We can add logic that will execute before a relayed call here.
     */
    function _preRelayedCall(
        bytes memory //context
    ) internal pure override returns (bytes32) {
        // No pre-call logic for now
        return bytes32(0);
    }

    /**
     * @dev Inheriting from GSNRecipient requires us to implement this function.
     *
     * We can add logic that will execute after a relayed call here.
     */
    function _postRelayedCall(
        bytes memory context,
        bool,
        uint256 actualCharge,
        bytes32
    ) internal override {
        // No post-call logic for now
    }
}
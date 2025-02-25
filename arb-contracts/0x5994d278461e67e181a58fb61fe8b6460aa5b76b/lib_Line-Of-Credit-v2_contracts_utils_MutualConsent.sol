// SPDX-License-Identifier: GPL-3.0
// Copyright: https://github.com/credit-cooperative/Line-Of-Credit-v2/blob/master/COPYRIGHT.md

// forked from https://github.com/IndexCoop/index-coop-smart-contracts/blob/master/contracts/lib/MutualConsent.sol

pragma solidity 0.8.25;

import {IMutualConsent} from "./lib_Line-Of-Credit-v2_contracts_interfaces_IMutualConsent.sol";

/**
 * @title MutualConsent
 * @author Set Protocol
 *
 * The MutualConsent contract contains a modifier for handling mutual consents between two parties
 */
contract MutualConsent is IMutualConsent {
    /* ============ State Variables ============ */

    // equivalent to longest msg.data bytes, ie addCredit
    uint256 constant MAX_DATA_LENGTH_BYTES = 292;

    // equivalent to any fn with no args, ie just a fn selector
    uint256 constant MIN_DATA_LENGTH_BYTES = 4;

    // Mapping of upgradable units and if consent has been initialized by other party
    mapping(bytes32 => address) public mutualConsentProposals;
    uint128 private _nonce;
    uint128 public proposalCount;

    error Unauthorized();
    error InvalidConsent();
    error NotUserConsent();

    // causes revert when the msg.data passed in has more data (ie arguments) than the largest known fn signature
    error UnsupportedMutualConsentFunction();

    /* ============ Events ============ */

    event MutualConsentRegistered(bytes32 indexed proposalId, address indexed taker, uint256 indexed nonce, bytes msgData);
    event MutualConsentRevoked(bytes32 indexed proposalId);
    event MutualConsentAccepted(bytes32 indexed proposalId);
    event MutualConsentRevokedAll(uint256 indexed newNonce);

    /* ============ Modifiers ============ */

    /**
     * @notice - allows a function to be called if only two specific stakeholders signoff on the tx data
     *         - signers can be anyone. only two signers per contract or dynamic signers per tx.
     */
    modifier mutualConsent(address _signerOne, address _signerTwo) {
        if (_mutualConsent(_signerOne, _signerTwo)) {
            // Run whatever code needed 2/2 consent
            _;
        }
    }

    /**
     *  @notice - allows a caller to revoke a previously created consent
     *  @dev    - MAX_DATA_LENGTH_BYTES is set at 164 bytes, which is the length of the msg.data
     *          - for the addCredit function. Anything over that is not valid and might be used in
     *          - an attempt to create a hash collision
     *  @param  _reconstructedMsgData The reconstructed msg.data for the function call for which the
     *          original consent was created - comprised of the fn selector (bytes4) and abi.encoded
     *          function arguments.
     *
     */
    function revokeConsent(uint256, bytes calldata _reconstructedMsgData) public virtual {
        if (
            _reconstructedMsgData.length > MAX_DATA_LENGTH_BYTES || _reconstructedMsgData.length < MIN_DATA_LENGTH_BYTES
        ) {
            revert UnsupportedMutualConsentFunction();
        }

        bytes32 proposalIdToDelete = keccak256(abi.encodePacked(_reconstructedMsgData, msg.sender, _nonce));

        address consentor = mutualConsentProposals[proposalIdToDelete];
        if (consentor == address(0)) {
            revert InvalidConsent();
        }
        if (consentor != msg.sender) {
            revert NotUserConsent();
        } // note: cannot test, as no way to know what data (+msg.sender) would cause hash collision

        --proposalCount;
        delete mutualConsentProposals[proposalIdToDelete];

        emit MutualConsentRevoked(proposalIdToDelete);
    }

    /* ============ Internal Functions ============ */

    function _mutualConsent(address _signerOne, address _signerTwo) internal returns (bool) {
        if (msg.sender != _signerOne && msg.sender != _signerTwo) {
            revert Unauthorized();
        }

        address nonCaller = _getNonCaller(_signerOne, _signerTwo);

        // The consent hash is defined by the hash of the transaction call data and sender of msg,
        // which uniquely identifies the function, arguments, and sender.
        uint128 nonce = _nonce;
        bytes32 expectedProposalId = keccak256(abi.encodePacked(msg.data, nonCaller, nonce));

        if (mutualConsentProposals[expectedProposalId] == address(0)) {
            bytes32 newProposalId = keccak256(abi.encodePacked(msg.data, msg.sender, nonce));
            if (mutualConsentProposals[newProposalId] != address(0)) {
                return false;
            }

            ++proposalCount;
            mutualConsentProposals[newProposalId] = msg.sender; // save caller's consent for nonCaller to accept

            emit MutualConsentRegistered(newProposalId, nonCaller, nonce, msg.data);

            return false;
        }

        --proposalCount;
        delete mutualConsentProposals[expectedProposalId];

        emit MutualConsentAccepted(expectedProposalId);

        return true;
    }

    function _clearProposals() internal {
        proposalCount = 0;
        emit MutualConsentRevokedAll(++_nonce);
    }

    function _getNonCaller(address _signerOne, address _signerTwo) internal view returns (address) {
        return msg.sender == _signerOne ? _signerTwo : _signerOne;
    }
}
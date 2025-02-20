// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.20;

import { SafeCast } from "./openzeppelin_contracts_utils_math_SafeCast.sol";
import { IERC6372 } from "./openzeppelin_contracts_interfaces_IERC6372.sol";
import { SafeERC20, IERC20 } from "./openzeppelin_contracts_token_ERC20_utils_SafeERC20.sol";

import { OAppCore } from "./layerzerolabs_lz-evm-oapp-v2_contracts_oapp_OAppReceiver.sol";

import { IVotesReadCallback, IVotesReader } from "./layerzerolabs_governance-evm-contracts_contracts_votes-reader_IVotesReader.sol";

/**
 * @title GovernorOVoteBase
 * @dev Abstract contract for handling vote-related operations in a governance system.
 */
abstract contract GovernorOVoteBase is OAppCore, IVotesReadCallback, IERC6372 {
    using SafeCast for uint256;
    using SafeERC20 for IERC20;

    // =============================== Structs ===============================

    /**
     * @dev Struct representing the data for a vote message.
     * @param proposalId The ID of the proposal being voted on.
     * @param voter The address of the voter.
     * @param castVoteTime The time the vote was cast.
     * @param support The support value for the vote.
     * @param reason The reason for the vote.
     * @param params Additional parameters for the vote.
     * @param snapshot The snapshot timestamp for the vote.
     * @param votes The number of votes.
     */
    struct MsgData {
        uint256 proposalId;
        address voter;
        uint64 castVoteTime;
        uint8 support;
        string reason;
        bytes params;
        uint64 snapshot;
        uint256 votes;
    }

    // =============================== Events ===============================

    event LzVoteCast(address indexed voter, uint256 indexed proposalId, uint8 support, string reason, bytes params);

    // =============================== Errors ===============================

    // @dev Error thrown when an unauthorized action is attempted.
    error Unauthorized();
    // @dev Error thrown when there is a read request in progress.
    error ReadRequestInProgress();

    // =============================== Variables ===============================

    /**
     * @dev The contract for reading votes.
     */
    IVotesReader public votesReader;

    uint256 internal inflightReadRequests;

    // =============================== Modifiers ===============================

    /**
     * @dev Modifier to restrict access to the votes reader.
     */
    modifier onlyVotesReader() {
        if (_msgSender() != address(votesReader)) revert Unauthorized();
        _;
    }

    /**
     * @dev Constructor to initialize the contract.
     * @param _endpoint The address of the LayerZero endpoint.
     * @param _delegate The address of the delegate.
     */
    constructor(address _endpoint, address _delegate) OAppCore(_endpoint, _delegate) {}

    // =============================== Setters ===============================

    /**
     * @notice Sets the votes reader contract.
     * @param _votesReaderContract The address of the votes reader contract.
     */
    function setVotesReader(address _votesReaderContract) external virtual onlyOwner {
        if (inflightReadRequests > 0) revert ReadRequestInProgress();

        votesReader = IVotesReader(_votesReaderContract);
    }

    // =============================== VotesReader Callbacks ===============================

    /**
     * @notice Callback function called when votes are received.
     * @param _voter The address of the voter.
     * @param _snapshot The snapshot timestamp.
     * @param _votes The number of votes received.
     * @param _extraData Additional data.
     */
    function onVotesReceived(
        address _voter,
        uint64 _snapshot,
        uint256 _votes,
        bytes calldata _extraData
    ) external payable virtual onlyVotesReader {
        inflightReadRequests--;

        _onVotesReceived(_voter, _snapshot, _votes, _extraData);
    }

    /**
     * @dev Internal function to handle received votes.
     * @param _voter The address of the voter.
     * @param _snapshot The snapshot timestamp.
     * @param _votes The number of votes received.
     * @param _extraData Additional data.
     */
    function _onVotesReceived(
        address _voter,
        uint64 _snapshot,
        uint256 _votes,
        bytes calldata _extraData
    ) internal virtual;

    // =============================== Internal Helpers ===============================

    /**
     * @dev Internal function to handle the payment of LayerZero token fee.
     * lzTokenFee will be transferred to the endpoint directly to save gas.
     * @param _lzTokenFee The LayerZero token fee.
     */
    function _payLzTokenFee(uint256 _lzTokenFee) internal virtual {
        if (_lzTokenFee > 0) {
            address lzToken = endpoint.lzToken();
            IERC20(lzToken).safeTransferFrom(_msgSender(), address(endpoint), _lzTokenFee);
        }
    }

    // =============================== EIP-6372 ===============================

    /**
     * @dev Clock (as specified in EIP-6372) is set to match the token's clock. Fallback to block numbers if the token
     * does not implement EIP-6372.
     * @return The current timestamp as a 48-bit integer.
     */
    function clock() public view virtual override returns (uint48) {
        return block.timestamp.toUint48();
    }

    /**
     * @dev Machine-readable description of the clock as specified in EIP-6372.
     * @return A string describing the clock mode.
     */
    // solhint-disable-next-line func-name-mixedcase
    function CLOCK_MODE() public view virtual override returns (string memory) {
        return "mode=timestamp&from=default";
    }
}
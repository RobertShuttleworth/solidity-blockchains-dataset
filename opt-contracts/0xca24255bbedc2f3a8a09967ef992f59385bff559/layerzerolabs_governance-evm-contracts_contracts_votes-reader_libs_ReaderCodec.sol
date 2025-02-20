// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.20;

import { EnumerableSet } from "./openzeppelin_contracts_utils_structs_EnumerableSet.sol";
import { SafeCast } from "./openzeppelin_contracts_utils_math_SafeCast.sol";

import { ReadCmdCodecV1, EVMCallComputeV1, EVMCallRequestV1 } from "./layerzerolabs_lz-evm-oapp-v2_contracts_oapp_libs_ReadCmdCodecV1.sol";

import { AggBalanceReader } from "./layerzerolabs_governance-evm-contracts_contracts_votes-reader_AggBalanceReader.sol";

/**
 * @dev Struct representing the configuration for reading data.
 * @param token The address of the token contract.
 * @param confirmations The number of confirmations required.
 */
struct ReadConfig {
    address token;
    uint16 confirmations;
}

/**
 * @title ReaderCodec
 * @dev Library for encoding and decoding read commands and responses.
 */
library ReaderCodec {
    using SafeCast for uint256;
    using EnumerableSet for EnumerableSet.UintSet;

    /**
     * @dev Struct representing the parameters for a votes command.
     * @param eid The chain ID.
     * @param voter The address of the voter.
     * @param snapshot The snapshot block number/timestamp.
     * @param snapshotSpan The span of the snapshot.
     * @param context Additional context data.
     */
    struct VotesCmdParam {
        uint32 eid;
        address voter;
        uint64 snapshot;
        uint64 snapshotSpan;
        bytes context;
    }

    error NoReadConfig();
    error InvalidSnapshotSpan();

    uint8 internal constant COMPUTE_TYPE_REDUCE = 1;

    uint16 internal constant CMD_TYPE_READ_VOTES = 1;

    uint16 internal constant REQUEST_BALANCE = 1;
    uint16 internal constant REQUEST_CONTEXT = 2;

    /**
     * @notice Constructs the command to read votes(balance) from multiple chains.
     * @param _readEidSet The set of chain IDs to read from.
     * @param _readConfigs The mapping of chain IDs to their read configurations.
     * @param _param The parameters for the votes command.
     * @return The constructed command as bytes.
     */
    function getVotesReadCmd(
        EnumerableSet.UintSet storage _readEidSet,
        mapping(uint32 => ReadConfig) storage _readConfigs,
        VotesCmdParam memory _param
    ) internal view returns (bytes memory) {
        uint256 readChainsLength = _readEidSet.length();
        if (readChainsLength == 0) revert NoReadConfig();

        if (_param.snapshotSpan == 0) revert InvalidSnapshotSpan();

        // request 2 data points per chain
        uint256 readRequestsLength = readChainsLength * 2 + 1; // +1 for context
        EVMCallRequestV1[] memory readRequests = new EVMCallRequestV1[](readRequestsLength);
        bytes memory callBalanceData = abi.encodeWithSignature("balanceOf(address)", _param.voter);
        for (uint i = 0; i < readChainsLength; ) {
            uint32 targetEid = uint32(_readEidSet.at(i));
            readRequests[i * 2] = EVMCallRequestV1({
                appRequestLabel: REQUEST_BALANCE,
                targetEid: targetEid,
                isBlockNum: false,
                blockNumOrTimestamp: _param.snapshot,
                confirmations: _readConfigs[targetEid].confirmations,
                to: _readConfigs[targetEid].token,
                callData: callBalanceData
            });
            readRequests[i * 2 + 1] = EVMCallRequestV1({
                appRequestLabel: REQUEST_BALANCE,
                targetEid: targetEid,
                isBlockNum: false,
                blockNumOrTimestamp: _param.snapshot - _param.snapshotSpan,
                confirmations: _readConfigs[targetEid].confirmations,
                to: _readConfigs[targetEid].token,
                callData: callBalanceData
            });

            unchecked {
                i++;
            }
        }

        // the last request is for context
        readRequests[readRequestsLength - 1] = EVMCallRequestV1({
            appRequestLabel: REQUEST_CONTEXT,
            targetEid: _param.eid, // current chain
            isBlockNum: false,
            blockNumOrTimestamp: block.timestamp.toUint64(),
            confirmations: _readConfigs[_param.eid].confirmations, // local chain confirmations
            to: address(this), // current address to read
            callData: abi.encodeWithSelector(AggBalanceReader.identity.selector, _param.context)
        });

        // compute with lzReduce on local chain
        EVMCallComputeV1 memory evmCompute = EVMCallComputeV1({
            computeSetting: COMPUTE_TYPE_REDUCE, // 1 for lzReduce only
            targetEid: _param.eid, // current chain
            isBlockNum: false,
            blockNumOrTimestamp: block.timestamp.toUint64(),
            confirmations: _readConfigs[_param.eid].confirmations, // local chain confirmations
            to: address(this) // current address to compute
        });

        return ReadCmdCodecV1.encode(CMD_TYPE_READ_VOTES, readRequests, evmCompute);
    }

    /**
     * @notice Encodes the read response.
     * @param _votes The number of votes.
     * @param _context Additional context data.
     * @return The encoded read response as bytes.
     */
    function encodeReadResponse(uint256 _votes, bytes memory _context) internal pure returns (bytes memory) {
        return abi.encodePacked(_votes, _context);
    }

    /**
     * @notice Decodes the read response.
     * @param _message The encoded read response.
     * @return votes The number of votes.
     * @return snapshot The snapshot block number.
     * @return voter The address of the voter.
     * @return extraData Additional data.
     */
    function decodeReadResponse(
        bytes calldata _message
    ) internal pure returns (uint256 votes, uint64 snapshot, address voter, bytes memory extraData) {
        votes = abi.decode(_message[0:32], (uint256));
        bytes memory context = _message[32:];
        (snapshot, voter, extraData) = decodeReadContext(context);
    }

    /**
     * @notice Encodes the context for Read.
     * @param _snapshot The snapshot block number/timestamp.
     * @param _voter The address of the voter.
     * @param _extraData Additional data.
     * @return The encoded context as bytes.
     */
    function encodeReadContext(
        uint64 _snapshot,
        address _voter,
        bytes memory _extraData
    ) internal pure returns (bytes memory) {
        return abi.encode(_snapshot, _voter, _extraData);
    }

    /**
     * @notice Decodes the context of Read.
     * @param _context The encoded context.
     * @return The decoded snapshot block number/timestamp, voter address, and additional data.
     */
    function decodeReadContext(bytes memory _context) internal pure returns (uint64, address, bytes memory) {
        return abi.decode(_context, (uint64, address, bytes));
    }
}
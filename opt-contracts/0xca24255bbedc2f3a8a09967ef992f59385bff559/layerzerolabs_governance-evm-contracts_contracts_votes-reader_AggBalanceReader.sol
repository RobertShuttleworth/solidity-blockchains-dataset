// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.20;

import { EnumerableSet } from "./openzeppelin_contracts_utils_structs_EnumerableSet.sol";
import { SafeCast } from "./openzeppelin_contracts_utils_math_SafeCast.sol";

import { ILayerZeroEndpointV2, MessagingFee, MessagingReceipt, Origin } from "./layerzerolabs_lz-evm-protocol-v2_contracts_interfaces_ILayerZeroEndpointV2.sol";
import { OAppRead } from "./layerzerolabs_lz-evm-oapp-v2_contracts_oapp_OAppRead.sol";
import { OptionsBuilder } from "./layerzerolabs_lz-evm-oapp-v2_contracts_oapp_libs_OptionsBuilder.sol";
import { IOAppComputerReduce } from "./layerzerolabs_lz-evm-oapp-v2_contracts_oapp_interfaces_IOAppComputerReduce.sol";

import { IVotesReadCallback, IVotesReader } from "./layerzerolabs_governance-evm-contracts_contracts_votes-reader_IVotesReader.sol";
import { ReaderCodec, ReadConfig } from "./layerzerolabs_governance-evm-contracts_contracts_votes-reader_libs_ReaderCodec.sol";

/**
 * @title AggBalanceReader
 * @dev Contract for aggregating balance reads across multiple chains.
 */
contract AggBalanceReader is OAppRead, IVotesReader, IOAppComputerReduce {
    using EnumerableSet for EnumerableSet.UintSet;
    using SafeCast for uint256;
    using OptionsBuilder for bytes;

    // =============================== Errors ===============================

    // @dev Error thrown when an unauthorized action is attempted.
    error Unauthorized();
    // @dev Error thrown when the response length is invalid.
    error InvalidResponseLength();
    // @dev Error thrown when the response data is invalid.
    error InvalidResponseData();

    // =============================== Structs ===============================

    /**
     * @dev Struct representing the parameters for setting read configuration.
     * @param eid The chain ID.
     * @param config The read configuration.
     */
    struct SetReadConfigParam {
        uint32 eid;
        ReadConfig config;
    }

    // =============================== Constants/Variables ===============================

    /**
     * @dev The basic data size for votes.
     */
    uint32 public constant BASIC_DATA_SIZE = 32; // votes(uint256), 32, lzReceive message = pack(votes, context)

    /**
     * @dev The local chain ID.
     */
    uint32 public immutable localEid;

    /**
     * @dev The read channel ID.
     */
    uint32 public immutable readChannel;

    /**
     * @dev The address of the governor.
     */
    address public immutable governor;

    /**
     * @dev The gas limit enforced for the lzReceive function.
     */
    uint128 public enforceGasLimit = 400_000; // default gas limit for the lzReceive

    /**
     * @dev The snapshot time span in seconds.
     */
    uint64 public snapshotTimeSpan = 300; // default span 5 minutes

    /**
     * @dev Set of chain IDs for reading.
     */
    EnumerableSet.UintSet internal readEidSet;

    /**
     * @dev Mapping of chain IDs to their read configurations.
     */
    mapping(uint32 => ReadConfig) public readConfigs;

    // =============================== Modifiers ===============================

    /**
     * @dev Modifier to restrict access to the governor.
     */
    modifier onlyGovernor() {
        if (_msgSender() != governor) revert Unauthorized();
        _;
    }

    /**
     * @dev Constructor to initialize the contract.
     * @param _endpoint The address of the LayerZero endpoint.
     * @param _governor The address of the governor.
     * @param _readChannel The read channel ID.
     */
    constructor(address _endpoint, address _governor, uint32 _readChannel) OAppRead(_endpoint, msg.sender) {
        localEid = ILayerZeroEndpointV2(_endpoint).eid();
        readChannel = _readChannel;
        governor = _governor;

        setReadChannel(_readChannel, true);
    }

    // =============================== Setters/Getters ===============================

    /**
     * @notice Sets the read configuration for multiple chains.
     * @param params The parameters for setting read configuration.
     */
    function setReadConfig(SetReadConfigParam[] memory params) external onlyOwner {
        for (uint256 i = 0; i < params.length; ) {
            SetReadConfigParam memory param = params[i];
            if (param.config.token != address(0)) {
                readEidSet.add(param.eid);
                readConfigs[param.eid] = param.config;
            } else {
                readEidSet.remove(param.eid);
                delete readConfigs[param.eid];
            }

            unchecked {
                i++;
            }
        }
    }

    /**
     * @notice Sets the snapshot time span.
     * @param _span The snapshot time span in seconds.
     */
    function setSnapshotTimeSpan(uint64 _span) external onlyOwner {
        if (_span == 0) revert ReaderCodec.InvalidSnapshotSpan();
        snapshotTimeSpan = _span;
    }

    /**
     * @notice Sets the gas limit enforced for the lzReceive function.
     * @param _gasLimit The gas limit.
     */
    function setEnforceGasLimit(uint128 _gasLimit) external onlyOwner {
        enforceGasLimit = _gasLimit;
    }

    /**
     * @notice Gets the read configuration for a specific chain ID.
     * @param _eid The chain ID.
     * @return The read configuration.
     */
    function getReadConfig(uint32 _eid) external view returns (ReadConfig memory) {
        return readConfigs[_eid];
    }

    /**
     * @notice Gets all the chain IDs for reading.
     * @return eids The array of chain IDs.
     */
    function getAllReadEids() external view returns (uint32[] memory eids) {
        uint256[] memory values = readEidSet.values();
        assembly {
            eids := values
        }
    }

    // ============================== IVotesReader ==============================

    /**
     * @notice Quotes the fee required to read votes.
     * @param _voter The address of the voter.
     * @param _snapshot The snapshot timestamp.
     * @param _extraData Additional data.
     * @param _options Additional options for the read operation.
     * @param _payInLzToken A boolean indicating whether to pay in LzToken.
     * @return The calculated messaging fee.
     */
    function quote(
        address _voter,
        uint64 _snapshot,
        bytes calldata _extraData,
        bytes calldata _options,
        bool _payInLzToken
    ) public view returns (MessagingFee memory) {
        bytes memory context = ReaderCodec.encodeReadContext(_snapshot, _voter, _extraData);
        bytes memory cmd = ReaderCodec.getVotesReadCmd(
            readEidSet,
            readConfigs,
            ReaderCodec.VotesCmdParam(localEid, _voter, _snapshot, snapshotTimeSpan, context)
        );
        bytes memory options = _buildLzReadOptions(_options, context.length.toUint32());
        return _quote(readChannel, cmd, options, _payInLzToken);
    }

    /**
     * @notice Reads votes and sends a read request.
     * @param _voter The address of the voter.
     * @param _snapshot The snapshot timestamp.
     * @param _extraData Additional data.
     * @param _options Additional options for the read operation.
     * @param _fee The fee for the read operation.
     * @param _refundAddress The address to refund any excess fee.
     * @return The messaging receipt.
     */
    function readVotes(
        address _voter,
        uint64 _snapshot,
        bytes calldata _extraData,
        bytes calldata _options,
        MessagingFee calldata _fee,
        address _refundAddress
    ) external payable onlyGovernor returns (MessagingReceipt memory) {
        bytes memory context = ReaderCodec.encodeReadContext(_snapshot, _voter, _extraData);
        bytes memory cmd = ReaderCodec.getVotesReadCmd(
            readEidSet,
            readConfigs,
            ReaderCodec.VotesCmdParam(localEid, _voter, _snapshot, snapshotTimeSpan, context)
        );
        bytes memory options = _buildLzReadOptions(_options, context.length.toUint32());
        return _lzSend(readChannel, cmd, options, _fee, _refundAddress);
    }

    // ============================== IOAppComputerReduce ==============================

    /**
     * @notice Reduces the responses from multiple chains.
     * @param *_cmd* The command data.
     * @param _responses The responses from multiple chains.
     * @return The reduced response as bytes.
     */
    function lzReduce(
        bytes calldata /*_cmd*/,
        bytes[] calldata _responses
    ) external pure override returns (bytes memory) {
        if (_responses.length == 0 || _responses.length % 2 != 1) revert InvalidResponseLength();

        uint256 totalVotes = 0;
        uint256 evenSnapshotVotes;
        for (uint256 i = 0; i < _responses.length - 1; ) {
            if (_responses[i].length != 32) revert InvalidResponseData(); // the response is abi.encode(uint256)

            uint256 votes = abi.decode(_responses[i], (uint256));
            if (i % 2 == 1) {
                totalVotes += votes < evenSnapshotVotes ? votes : evenSnapshotVotes; // min(votes, evenSnapshotVotes)
            } else {
                evenSnapshotVotes = votes;
            }

            unchecked {
                i++;
            }
        }

        // the last one is the context, abi.encode(bytes)
        bytes memory context = abi.decode(_responses[_responses.length - 1], (bytes));
        return ReaderCodec.encodeReadResponse(totalVotes, context);
    }

    // ================================= Receive =================================

    /**
     * @notice Handles the received LayerZero message.
     */
    function _lzReceive(
        Origin calldata /*_origin*/,
        bytes32 /*_guid*/,
        bytes calldata _message,
        address /*_executor*/,
        bytes calldata /*_extraData*/
    ) internal override {
        (uint256 votes, uint64 snapshot, address voter, bytes memory extraData) = ReaderCodec.decodeReadResponse(
            _message
        );

        IVotesReadCallback(governor).onVotesReceived{ value: msg.value }(voter, snapshot, votes, extraData);
    }

    // ======================= LzRead Util =======================

    /**
     * @notice Returns the input data as is.
     * This is useful for readVotes with additional data in lzReceive as context
     * @param _data The input data.
     * @return The same input data.
     */
    function identity(bytes calldata _data) external pure returns (bytes memory) {
        return _data;
    }

    // ======================= Internal =======================

    /**
     * @notice Handles the payment of LayerZero token fee.
     * @param *_lzTokenFee* The LayerZero token fee.
     */
    function _payLzToken(uint256 /*_lzTokenFee*/) internal virtual override {
        // @dev Cannot cache the token because it is not immutable in the endpoint.
        address lzToken = endpoint.lzToken();
        if (lzToken == address(0)) revert LzTokenUnavailable();

        // Assume the sender has paid LZ token fee by sending tokens to the endpoint for gas save.
    }

    /**
     * @notice Builds the LayerZero read options.
     * @param _options The input options.
     * @param _extraDataSize The size of the extra data.
     * @return The built options.
     */
    function _buildLzReadOptions(
        bytes memory _options,
        uint32 _extraDataSize
    ) internal view virtual returns (bytes memory) {
        if (_options.length == 0) {
            _options = OptionsBuilder.newOptions();
        }
        // lzReceive message = pack(basic_data, context), so the dataSize is BASIC_DATA_SIZE + _extraDataSize
        return _options.addExecutorLzReadOption(enforceGasLimit, BASIC_DATA_SIZE + _extraDataSize, 0);
    }
}
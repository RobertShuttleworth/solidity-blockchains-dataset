// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {AccessControl} from "./lib_openzeppelin-contracts_contracts_access_AccessControl.sol";
import {VerifyTypedData} from "./src_VerifyTypedData.sol";
import {WriterStorage} from "./src_WriterStorage.sol";

contract Writer is AccessControl, VerifyTypedData {
    bytes32 public constant CREATE_TYPEHASH = keccak256("Create(uint256 nonce,uint256 chunkCount)");
    bytes32 public constant CREATE_WITH_CHUNK_TYPEHASH =
        keccak256("CreateWithChunk(uint256 nonce,uint256 chunkCount,string chunkContent)");
    bytes32 public constant UPDATE_TYPEHASH =
        keccak256("Update(uint256 nonce,uint256 entryId,uint256 chunkIndex,string chunkContent)");
    bytes32 public constant REMOVE_TYPEHASH = keccak256("Remove(uint256 nonce,uint256 id)");
    bytes32 public constant ADD_CHUNK_TYPEHASH =
        keccak256("AddChunk(uint256 nonce,uint256 entryId,uint256 chunkIndex,string chunkContent)");
    bytes32 public constant SET_TITLE_TYPEHASH = keccak256("SetTitle(uint256 nonce,string title)");

    bytes public DOMAIN_NAME = "Writer";
    bytes public DOMAIN_VERSION = "1";
    bytes32 public WRITER_ROLE = keccak256("WRITER");

    WriterStorage public store;
    mapping(bytes32 => bool) public signatureWasExecuted;

    string public title;

    modifier authedBySig(bytes memory signature, bytes32 structHash) {
        address signer = getSigner(signature, structHash);
        require(hasRole(WRITER_ROLE, signer), "Writer: Signer is not a manager");
        require(!signatureWasExecuted[keccak256(signature)], "Writer: Signature has already been executed");
        _;
        signatureWasExecuted[keccak256(signature)] = true;
    }

    event StorageSet(address indexed storageAddress);

    constructor(string memory newTitle, address storageAddress, address admin, address[] memory writers)
        VerifyTypedData(DOMAIN_NAME, DOMAIN_VERSION)
    {
        store = WriterStorage(storageAddress);
        title = newTitle;

        _grantRole(DEFAULT_ADMIN_ROLE, admin);
        uint256 length = writers.length;
        for (uint256 i = 0; i < length; i++) {
            _grantRole(WRITER_ROLE, writers[i]);
        }
        emit StorageSet(storageAddress);
    }

    function setNewAdmin(address newAdmin) external onlyRole(DEFAULT_ADMIN_ROLE) {
        _grantRole(DEFAULT_ADMIN_ROLE, newAdmin);
        _revokeRole(DEFAULT_ADMIN_ROLE, msg.sender);
    }

    function setStorage(address storageAddress) external onlyRole(DEFAULT_ADMIN_ROLE) {
        store = WriterStorage(storageAddress);
        emit StorageSet(storageAddress);
    }

    function getEntryCount() external view returns (uint256) {
        return store.getEntryCount();
    }

    function getEntryIds() external view returns (uint256[] memory) {
        return store.getEntryIds();
    }

    function getEntry(uint256 id) external view returns (WriterStorage.Entry memory) {
        return store.getEntry(id);
    }

    function getEntryContent(uint256 id) external view returns (string memory) {
        return store.getEntryContent(id);
    }

    function getEntryChunk(uint256 id, uint256 index) external view returns (string memory) {
        return store.getEntry(id).chunks[index];
    }

    function getEntryTotalChunks(uint256 id) external view returns (uint256) {
        return store.getEntryTotalChunks(id);
    }

    function setTitle(string calldata newTitle) external onlyRole(DEFAULT_ADMIN_ROLE) {
        title = newTitle;
    }

    function setTitleWithSig(bytes memory signature, uint256 nonce, string calldata newTitle)
        external
        authedBySig(signature, keccak256(abi.encode(SET_TITLE_TYPEHASH, nonce, keccak256(abi.encodePacked(newTitle)))))
    {
        title = newTitle;
    }

    function create(uint256 chunkCount) external onlyRole(WRITER_ROLE) {
        _create(chunkCount, msg.sender);
    }

    function createWithSig(bytes memory signature, uint256 nonce, uint256 chunkCount)
        external
        authedBySig(signature, keccak256(abi.encode(CREATE_TYPEHASH, nonce, chunkCount)))
    {
        address signer = getSigner(signature, keccak256(abi.encode(CREATE_TYPEHASH, nonce, chunkCount)));
        _create(chunkCount, signer);
    }

    function createWithChunk(uint256 chunkCount, string calldata chunkContent) external onlyRole(WRITER_ROLE) {
        _createWithChunk(chunkCount, chunkContent, msg.sender);
    }

    function createWithChunkWithSig(
        bytes memory signature,
        uint256 nonce,
        uint256 chunkCount,
        string calldata chunkContent
    )
        external
        authedBySig(
            signature,
            keccak256(abi.encode(CREATE_WITH_CHUNK_TYPEHASH, nonce, chunkCount, keccak256(abi.encodePacked(chunkContent))))
        )
    {
        address signer = getSigner(
            signature,
            keccak256(
                abi.encode(CREATE_WITH_CHUNK_TYPEHASH, nonce, chunkCount, keccak256(abi.encodePacked(chunkContent)))
            )
        );
        _createWithChunk(chunkCount, chunkContent, signer);
    }

    function update(uint256 entryId, uint256 chunkIndex, string calldata chunkContent) external onlyRole(WRITER_ROLE) {
        _update(entryId, chunkIndex, chunkContent, msg.sender);
    }

    function updateWithSig(
        bytes memory signature,
        uint256 nonce,
        uint256 entryId,
        uint256 chunkIndex,
        string calldata chunkContent
    )
        external
        authedBySig(
            signature,
            keccak256(abi.encode(UPDATE_TYPEHASH, nonce, entryId, chunkIndex, keccak256(abi.encodePacked(chunkContent))))
        )
    {
        address signer = getSigner(
            signature,
            keccak256(
                abi.encode(UPDATE_TYPEHASH, nonce, entryId, chunkIndex, keccak256(abi.encodePacked(chunkContent)))
            )
        );
        _update(entryId, chunkIndex, chunkContent, signer);
    }

    function remove(uint256 entryId) external onlyRole(WRITER_ROLE) {
        _remove(entryId, msg.sender);
    }

    function removeWithSig(bytes memory signature, uint256 nonce, uint256 entryId)
        external
        authedBySig(signature, keccak256(abi.encode(REMOVE_TYPEHASH, nonce, entryId)))
    {
        address signer = getSigner(signature, keccak256(abi.encode(REMOVE_TYPEHASH, nonce, entryId)));
        _remove(entryId, signer);
    }

    function addChunk(uint256 entryId, uint256 chunkIndex, string calldata chunkContent)
        external
        onlyRole(WRITER_ROLE)
    {
        _addChunk(entryId, chunkIndex, chunkContent, msg.sender);
    }

    function addChunkWithSig(
        bytes memory signature,
        uint256 nonce,
        uint256 entryId,
        uint256 chunkIndex,
        string calldata chunkContent
    )
        external
        authedBySig(
            signature,
            keccak256(abi.encode(ADD_CHUNK_TYPEHASH, nonce, entryId, chunkIndex, keccak256(abi.encodePacked(chunkContent))))
        )
    {
        address signer = getSigner(
            signature,
            keccak256(
                abi.encode(ADD_CHUNK_TYPEHASH, nonce, entryId, chunkIndex, keccak256(abi.encodePacked(chunkContent)))
            )
        );
        _addChunk(entryId, chunkIndex, chunkContent, signer);
    }

    function _create(uint256 chunkCount, address author) private {
        store.create(chunkCount, author);
    }

    function _createWithChunk(uint256 chunkCount, string calldata chunkContent, address author) private {
        store.createWithChunk(chunkCount, chunkContent, author);
    }

    function _update(uint256 entryId, uint256 chunkIndex, string calldata chunkContent, address author) private {
        store.update(entryId, chunkIndex, chunkContent, author);
    }

    function _remove(uint256 id, address author) private {
        store.remove(id, author);
    }

    function _addChunk(uint256 entryId, uint256 chunkIndex, string calldata chunkContent, address author) private {
        store.addChunk(entryId, chunkIndex, chunkContent, author);
    }
}
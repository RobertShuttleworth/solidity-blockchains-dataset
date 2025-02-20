// SPDX-License-Identifier: MIT

pragma solidity ^0.8.14;

import "./openzeppelin_contracts_access_Ownable.sol";
import "./contracts_interface_IMixtureBlockUpdater.sol";

contract OptimisticBlockUpdater is IMixtureBlockUpdater, Ownable {
    address public blockRouter;

    IMixtureBlockUpdater public oldBlockUpdater;

    // blockHash=>receiptsRoot =>BlockConfirmation
    mapping(bytes32 => mapping(bytes32 => uint256)) public blockInfos;

    modifier onlyBlockRouter() {
        require(msg.sender == blockRouter, "caller is not the block router");
        _;
    }

    constructor(address _blockRouter) {
        blockRouter = _blockRouter;
    }

    function importBlock(
        uint256 blockNumber,
        bytes32 _blockHash,
        bytes32 _receiptsRoot,
        uint256 _blockConfirmation
    ) external onlyBlockRouter {
        (bool exist, uint256 blockConfirmation) = _checkBlock(_blockHash, _receiptsRoot);
        require(_blockConfirmation > 0, "invalid blockConfirmation");
        if (exist && _blockConfirmation <= blockConfirmation) {
            return;
        }
        blockInfos[_blockHash][_receiptsRoot] = _blockConfirmation;
        emit ImportBlock(blockNumber, _blockHash, _receiptsRoot);
    }

    function checkBlock(bytes32 _blockHash, bytes32 _receiptHash) external view returns (bool) {
        (bool exist, ) = _checkBlock(_blockHash, _receiptHash);
        return exist;
    }

    function checkBlockConfirmation(bytes32 _blockHash, bytes32 _receiptHash) external view returns (bool, uint256) {
        return _checkBlock(_blockHash, _receiptHash);
    }

    function _checkBlock(bytes32 _blockHash, bytes32 _receiptHash) internal view returns (bool, uint256) {
        uint256 blockConfirmation = blockInfos[_blockHash][_receiptHash];
        if (blockConfirmation > 0) {
            return (true, blockConfirmation);
        }
        if (address(oldBlockUpdater) != address(0)) {
            return oldBlockUpdater.checkBlockConfirmation(_blockHash, _receiptHash);
        }
        return (false, 0);
    }

    //----------------------------------------------------------------------------------
    // onlyOwner
    function setBlockRouter(address _blockRouter) external onlyOwner {
        require(_blockRouter != address(0), "Zero address");
        blockRouter = _blockRouter;
    }

    function setOldBlockUpdater(address _oldBlockUpdater) external onlyOwner {
        oldBlockUpdater = IMixtureBlockUpdater(_oldBlockUpdater);
    }
}
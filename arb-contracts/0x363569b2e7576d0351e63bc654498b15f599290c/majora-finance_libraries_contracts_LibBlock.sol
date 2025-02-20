// SPDX-License-Identifier: AGPL-3.0
pragma solidity ^0.8.20;

import "./majora-finance_libraries_contracts_DataTypes.sol";



/**
 * @title LibBlock - A library for managing blocks parameter in Majora Vault context
 * @author Majora Development Association
 * @notice This library provides functions to manage dynamic, strategy, and harvest block data
 * @dev The library uses storage slots to ensure unique locations for each block type, avoiding collisions
 */
library LibBlock {

    // Define constants for storage slots
    bytes32 constant STRATEGY_BLOCKS_STORAGE_POSITION = keccak256("strategy.blocks.majora.finance");
    bytes32 constant HARVEST_BLOCKS_STORAGE_POSITION = keccak256("harvest.blocks.majora.finance");
    bytes32 constant DYNAMIC_BLOCKS_STORAGE_POSITION = keccak256("dynamic.blocks.majora.finance");

    /// @notice Error triggered when the strategy enter function reverts
    /// @param _block The address of the strategy block
    /// @param _index The index of the strategy block
    /// @param _data The data associated with the revert
    error StrategyEnterReverted(address _block, uint256 _index, bytes _data);

    /// @notice Error triggered when the strategy exit function reverts
    /// @param _block The address of the strategy block
    /// @param _index The index of the strategy block
    /// @param _data The data associated with the revert
    error StrategyExitReverted(address _block, uint256 _index, bytes _data);

    /// @notice Error triggered when the oracle exit function reverts
    /// @param _block The address of the oracle block
    /// @param _index The index of the oracle block
    /// @param _data The data associated with the revert
    error OracleExitReverted(address _block, uint256 _index, bytes _data);

    /// @notice Error triggered when the harvest function reverts
    /// @param _block The address of the harvest block
    /// @param _index The index of the harvest block
    /// @param _data The data associated with the revert
    error HarvestReverted(address _block, uint256 _index, bytes _data);

    /// @notice Error triggered when the hook function reverts
    /// @param _block The address of the harvest block
    /// @param _index The index of the harvest block
    /// @param _data The data associated with the revert
    error HookReverted(address _block, uint256 _index, bytes _data);

    /// @notice Holds block storage mapping for strategy and harvest blocks
    struct BlocksStorage {
        mapping(uint256 => bytes) storagePerIndex;
    }

    /// @notice Holds dynamic block storage mapping
    struct DynamicBlocksStorage {
        mapping(uint256 => bytes) dynamicStorePerIndex;
    }

    /**
     * @notice Retrieves the storage instance for dynamic blocks parameters
     * @dev The storage position is derived from a constant hash to ensure its uniqueness
     * @return ds The dynamic block storage structure
     */
    function dynamicBlocksStorage() internal pure returns (DynamicBlocksStorage storage ds) {
        bytes32 position = DYNAMIC_BLOCKS_STORAGE_POSITION;
        assembly {
            ds.slot := position
        }
    }

    /**
     * @notice Sets up data for dynamic block parameters
     * @param _index The block index for which to setup the block data
     * @param _data The data to associate with the block
     */
    function setupDynamicBlockData(uint256 _index, bytes memory _data) internal {
        dynamicBlocksStorage().dynamicStorePerIndex[_index] = _data;
    }

    /**
     * @notice Clears data for a dynamic block parameters
     * @param _index The index of the dynamic block parameters to clear
     */
    function purgeDynamicBlockData(uint256 _index) internal {
        delete (dynamicBlocksStorage().dynamicStorePerIndex[_index]);
    }

    /**
     * @notice Retrieves data for dynamic block parameters
     * @param _index The index of the dynamic block parameters to retrieve
     * @return The data associated with the dynamic block parameters
     */
    function getDynamicBlockData(uint256 _index) internal view returns (bytes memory) {
        return dynamicBlocksStorage().dynamicStorePerIndex[_index];
    }

   
    /**
     * @notice Retrieves the storage instance for strategy blocks parameters
     * @dev The storage position is derived from a constant hash to ensure its uniqueness
     * @return ds The strategy block storage structure
     */
    function strategyBlocksStorage() internal pure returns (BlocksStorage storage ds) {
        bytes32 position = STRATEGY_BLOCKS_STORAGE_POSITION;
        assembly {
            ds.slot := position
        }
    }

    /**
     * @notice Retrieves data for strategy block parameters
     * @param _index The index of the strategy block parameters to retrieve
     * @return The data associated with the strategy block parameters
     */
    function getStrategyStorageByIndex(uint256 _index) internal view returns (bytes memory) {
        BlocksStorage storage store = strategyBlocksStorage();
        return store.storagePerIndex[_index];
    }

    /**
     * @notice Sets up data for strategy block parameters
     * @param _index The block index for which to setup the block data
     * @param _data The data to associate with the block
     */
    function setupStrategyBlockData(uint256 _index, bytes memory _data) internal {
        BlocksStorage storage store = strategyBlocksStorage();
        store.storagePerIndex[_index] = _data;
    }

    /**
     * @notice Executes an 'enter' operation on a strategy block
     * @dev This calls the 'enter' function on the strategy block using delegatecall
     * @param _block The address of the strategy block
     * @param _index The index of the strategy block
     */
    function executeStrategyEnter(address _block, uint256 _index) internal {
        (bool success, bytes memory _data) = _block.delegatecall(abi.encodeWithSignature("enter(uint256)", _index));

        if (!success) revert StrategyEnterReverted(_block, _index, _data);
    }

    /**
     * @notice Executes an 'exit' operation on a strategy block
     * @dev This calls the 'exit' function on the strategy block using delegatecall
     * @param _block The address of the strategy block
     * @param _index The index of the strategy block
     * @param _percent The percentage of the assets to exit
     */
    function executeStrategyExit(address _block, uint256 _index, uint256 _percent) internal {
        (bool success, bytes memory _data) =
            _block.delegatecall(abi.encodeWithSignature("exit(uint256,uint256)", _index, _percent));

        if (!success) revert StrategyExitReverted(_block, _index, _data);
    }

    /**
     * @notice Retrieves the storage instance for harvest blocks parameters
     * @dev The storage position is derived from a constant hash to ensure its uniqueness
     * @return ds The harvest block storage structure
     */
    function harvestBlocksStorage() internal pure returns (BlocksStorage storage ds) {
        bytes32 position = HARVEST_BLOCKS_STORAGE_POSITION;
        assembly {
            ds.slot := position
        }
    }

    /**
     * @notice Retrieves data for harvest block parameters
     * @param _index The index of the harvest block parameters to retrieve
     * @return The data associated with the harvest block parameters
     */
    function getHarvestStorageByIndex(uint256 _index) internal view returns (bytes memory) {
        BlocksStorage storage store = harvestBlocksStorage();
        return store.storagePerIndex[_index];
    }

    /**
     * @notice Sets up data for harvest block parameters
     * @param _index The block index for which to setup the block data
     * @param _data The data to associate with the block
     */
    function setupHarvestBlockData(uint256 _index, bytes memory _data) internal {
        BlocksStorage storage store = harvestBlocksStorage();
        store.storagePerIndex[_index] = _data;
    }

    /**
     * @notice Executes a 'harvest' operation on a harvest block
     * @dev This calls the 'harvest' function on the harvest block using delegatecall
     * @param _block The address of the harvest block
     * @param _index The index of the harvest block to perform
     */
    function executeHarvest(address _block, uint256 _index) internal {
        (bool success, bytes memory _data) = _block.delegatecall(abi.encodeWithSignature("harvest(uint256)", _index));

        if (!success) revert HarvestReverted(_block, _index, _data);
    }

    /**
     * @notice Executes a 'hook' operation on a strategy block
     * @dev This calls the 'hook' function on the strategy block using delegatecall
     * @param _block The address of the strategy block
     * @param _index The index of the strategy block to perform
     */
    function executeHook(address _block, uint256 _index, DataTypes.BlockExecutionType _executionType) internal {
        (bool success, bytes memory _data) = _block.delegatecall(abi.encodeWithSignature("hook(uint256,uint8)", _index, _executionType));

        if (!success) revert HookReverted(_block, _index, _data);
    }
}
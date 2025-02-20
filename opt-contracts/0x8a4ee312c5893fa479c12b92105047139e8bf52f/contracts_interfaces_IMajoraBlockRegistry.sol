// SPDX-License-Identifier: AGPL-3.0
pragma solidity ^0.8.20;

/**
 * @title Interface of Majora Block Registry
 * @author Majora Development Association
 * @notice A contract for registering Strategy blocks.
 */
interface IMajoraBlockRegistry {

    /**
     * @notice Block data 
     */
    struct MajoraBlockData {
        bool enabled;
        string name;
    }

    /**
     * @notice Error thrown when the caller is not the owner
     */
    error NotOwner();

    /**
     * @notice Error thrown when the caller is not the deployer
     */
    error NotDeployer();

    /**
     * @notice Error thrown when trying to add a block that is already registered
     */
    error BlockAlreadyExists();

    /**
     * @notice Event emitted when a block is added to the registry
     * @param addr Address of the block added
     * @param name Name of the block added
     */
    event NewBlock(address addr, string name);

    /**
     * @notice Event emitted when a block is removed from the registry
     * @param addr Address of the block removed
     */
    event RemoveBlock(address addr);

    /**
     *  @notice Adds multiple blocks to the registry.
     *  @param _blocks Array of block addresses to be added.
     *  @param _names Array of names corresponding to the Strategy blocks.
     */
    function addBlocks(address[] memory _blocks, string[] memory _names) external;

    /**
     * @notice Removes multiple blocks from the registry.
     * @param _blocks Array of block addresses to be removed.
     */
    function removeBlocks(address[] memory _blocks) external;

    /**
     * @notice Checks if the given blocks are valid (enabled).
     * @param _blocks _blocks Array of block addresses to be checked.
     * @return A boolean indicating whether all the blocks are valid.
     */
    function blocksValid(address[] memory _blocks) external view returns (bool);
    
    /**
     * @notice Retrieves the data of the given blocks.
     * @param _blocks Array of block addresses.
     * @return An array of MajoraBlockData containing the data of the blocks.
     */
    function getBlocks(address[] memory _blocks) external view returns (MajoraBlockData[] memory);
}
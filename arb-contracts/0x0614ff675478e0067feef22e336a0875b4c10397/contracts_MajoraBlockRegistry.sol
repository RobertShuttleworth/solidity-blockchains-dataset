// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.20;

import "./openzeppelin_contracts_access_Ownable.sol";
import "./openzeppelin_contracts_utils_Strings.sol";
import "./openzeppelin_contracts_access_manager_AccessManaged.sol";

import "./contracts_interfaces_IMajoraBlockRegistry.sol";

/**
 * @title MajoraBlockRegistry
 * @author Majora Development Association
 * @notice A contract for registering strategy blocks.
 */
contract MajoraBlockRegistry is
    AccessManaged,
    IMajoraBlockRegistry
{
    /**
     * @notice The number of blocks registered
     */
    uint256 public blocksLength;

    /**
     * @notice The mapping of blocks
     */
    mapping(address => MajoraBlockData) public blocks;

    /**
     * @notice Constructor
     * @param _authority The address of the access manager authority
     */
    constructor(address _authority) AccessManaged(_authority) {}

    /**
     *  @notice Adds multiple blocks to the registry.
     *  @param _blocks Array of block addresses to be added.
     *  @param _names Array of names corresponding to the strategy blocks.
     */
    function addBlocks(address[] memory _blocks, string[] memory _names) external restricted {
        for (uint256 i = 0; i < _blocks.length; i++) {
            if (blocks[_blocks[i]].enabled) revert BlockAlreadyExists();
            blocks[_blocks[i]] = MajoraBlockData({enabled: true, name: _names[i]});

            emit NewBlock(_blocks[i], _names[i]);
        }

        blocksLength = blocksLength + _blocks.length;
    }

    /**
     * @notice Removes multiple blocks from the registry.
     * @param _blocks Array of block addresses to be removed.
     */
    function removeBlocks(address[] memory _blocks) external restricted {
        for (uint256 i = 0; i < _blocks.length; i++) {
            MajoraBlockData storage b = blocks[_blocks[i]];
            if (b.enabled) {
                delete b.enabled;
                delete b.name;

                emit RemoveBlock(_blocks[i]);
                blocksLength = blocksLength - 1;
            }
        }
    }

    /**
     * @notice Checks if the given blocks are valid (enabled).
     * @param _blocks _blocks Array of block addresses to be checked.
     * @return A boolean indicating whether all the blocks are valid.
     */
    function blocksValid(address[] memory _blocks) external view returns (bool) {
        for (uint256 i = 0; i < _blocks.length; i++) {
            MajoraBlockData storage b = blocks[_blocks[i]];
            if (!b.enabled) {
                return false;
            }
        }

        return true;
    }

    /**
     * @notice Retrieves the data of the given blocks.
     * @param _blocks Array of block addresses.
     * @return An array of MajoraBlockData containing the data of the blocks.
     */
    function getBlocks(address[] memory _blocks) external view returns (MajoraBlockData[] memory) {
        MajoraBlockData[] memory blocksArray = new MajoraBlockData[](
            _blocks.length
        );

        for (uint256 i = 0; i < _blocks.length; i++) {
            blocksArray[i] = blocks[_blocks[i]];
        }

        return blocksArray;
    }
}
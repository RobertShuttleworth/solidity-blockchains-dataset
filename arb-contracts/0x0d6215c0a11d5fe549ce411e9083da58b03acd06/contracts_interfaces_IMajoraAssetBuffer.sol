// SPDX-License-Identifier: AGPL-3.0
pragma solidity ^0.8.20;

/**
 * @title Interface of Majora Asset Buffer
 * @author Majora Development Association
 * @notice Minimalistic mutualized buffer for vault. It is used to put buffered assets outside the vault strategies accounting
 */
interface IMajoraAssetBuffer {
    /**
     * @notice Puts the specified amount of assets into the buffer.
     * @param _asset Address of the asset to be buffered.
     * @param _amount Amount of the asset to be buffered.
     */
    function putInBuffer(address _asset, uint256 _amount) external;
}
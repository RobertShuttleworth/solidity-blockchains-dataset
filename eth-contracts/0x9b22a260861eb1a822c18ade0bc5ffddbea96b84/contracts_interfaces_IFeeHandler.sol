// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

interface IFeeHandler {
    // Event emitted when a fee is updated
    event FeeUpdated(uint8 version, uint256 newFee);

    /**
     * @dev Set or update the fee for a specific contract version
     * @param _version The contract version
     * @param _fee The fee amount in wei
     */
    function setFee(uint8 _version, uint256 _fee) external;

    /**
     * @dev Get the fee for a specific contract version
     * @param _version The contract version
     * @return The fee amount in wei
     */
    function getFee(uint8 _version) external view returns (uint256);

    /**
     * @dev Get the fee for a specific contract version
     * @param _version The contract version
     * @return The fee amount in wei
     */
    function feesByVersion(uint8 _version) external view returns (uint256);
}
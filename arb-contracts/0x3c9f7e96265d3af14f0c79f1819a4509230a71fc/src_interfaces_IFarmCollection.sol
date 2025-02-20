// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.10;

import "./lib_openzeppelin-contracts_contracts_token_ERC721_IERC721.sol";

/// @notice Interface for interacting with the main FarmCollection contract
/// @dev Defines required functions from the FarmCollection contract
interface IFarmCollection is IERC721 {
    /// @notice Function to mint NFT with operator privileges
    /// @param to Address to receive the NFT
    /// @param imageId Unique identifier for the image
    function mintWithOperator(address to, string calldata imageId) external;

    /// @notice Function to get the current token ID
    /// @return Current token ID in the collection
    function currentTokenId() external view returns (uint256);
}
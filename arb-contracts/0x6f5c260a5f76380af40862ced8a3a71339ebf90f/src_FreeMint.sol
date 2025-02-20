// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import "./src_interfaces_IFarmCollection.sol";
import "./lib_openzeppelin-contracts_contracts_access_AccessControl.sol";
import "./src_libraries_Errors.sol";
import "./lib_openzeppelin-contracts_contracts_utils_structs_EnumerableSet.sol";

/// @title FreeMint
/// @notice This contract manages free minting functionality for holders of specific NFT tokens
/// from the main FarmCollection contract
/// @dev Implements AccessControl for permission management and interacts with FarmCollection contract
contract FreeMint is AccessControl {
    using EnumerableSet for EnumerableSet.UintSet;

    /// @notice Set of eligible token IDs
    EnumerableSet.UintSet private eligibleTokenIds;

    /// @notice Error thrown when the token is not eligible for free mint
    error TokenIdNotEligible();

    /// @notice Error thrown when a token has already been used for free mint
    error TokenAlreadyClaimed();

    /// @notice Reference to the main FarmCollection contract
    /// @dev Used to call mintWithOperator function and check token ownership
    IFarmCollection public immutable farmCollection;

    /// @notice Tracks whether a token has been used for free mint
    /// @dev Maps tokenId to boolean indicating usage status
    mapping(uint256 => bool) public claimedTokenIds;

    /// @notice Emitted when a free mint is completed
    /// @param to Address that received the NFT
    /// @param usedTokenId Token ID used for claiming free mint
    /// @param imageId Unique identifier of the minted image
    event FreeMinted(address indexed to, uint256 indexed usedTokenId, string imageId);

    /// @notice Emitted when token eligibility is updated
    /// @param tokenIds Array of token IDs whose status was updated
    /// @param status New eligibility status
    event TokenIdsEligibilityUpdated(uint256[] tokenIds, bool status);

    /// @notice Initializes the FreeMint contract with the FarmCollection address
    /// @dev Grants DEFAULT_ADMIN_ROLE to the deployer
    /// @param _farmCollection Address of the existing FarmCollection contract
    constructor(address _farmCollection) {
        if (_farmCollection == address(0)) revert Errors.InvalidAddress();

        farmCollection = IFarmCollection(_farmCollection);
        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
    }

    /// @notice Allows admin to update eligibility status for multiple token IDs
    /// @dev Only callable by addresses with DEFAULT_ADMIN_ROLE
    /// @param tokenIds Array of token IDs to update
    /// @param status Eligibility status to set for all tokens
    function setEligibleTokenIds(uint256[] calldata tokenIds, bool status) external onlyRole(DEFAULT_ADMIN_ROLE) {
        for (uint i = 0; i < tokenIds.length; i++) {
            if (status) {
                eligibleTokenIds.add(tokenIds[i]);
            } else {
                eligibleTokenIds.remove(tokenIds[i]);
            }
        }

        emit TokenIdsEligibilityUpdated(tokenIds, status);
    }

    /// @notice Allows eligible token holders to mint one NFT for free
    /// @dev Verifies token ownership and eligibility before minting
    /// @param tokenId Token ID being used to claim free mint
    /// @param imageId Unique identifier for the new NFT image
    function freeMint(uint256 tokenId, string calldata imageId) external {
        if (!eligibleTokenIds.contains(tokenId)) revert TokenIdNotEligible();
        if (claimedTokenIds[tokenId]) revert TokenAlreadyClaimed();
        if (farmCollection.ownerOf(tokenId) != msg.sender) revert Errors.NotAuthorized();

        claimedTokenIds[tokenId] = true;
        farmCollection.mintWithOperator(msg.sender, imageId);

        emit FreeMinted(msg.sender, tokenId, imageId);
    }

    /// @notice Get all eligible token IDs for a given address
    /// @dev Returns an array of token IDs that the user owns and can use for free mint
    /// @param user Address to check for eligible tokens
    /// @return tokenIds Array of eligible token IDs owned by the user
    function getEligibleTokenIdsForUser(address user) external view returns (uint256[] memory) {
        uint256 totalEligible = eligibleTokenIds.length();
        uint256[] memory results = new uint256[](totalEligible);

        uint256 count = 0;

        // First count eligible tokens for user
        for (uint256 i = 0; i < totalEligible; i++) {
            uint256 tokenId = eligibleTokenIds.at(i);
            if (farmCollection.ownerOf(tokenId) == user && !claimedTokenIds[tokenId]) {
                results[count++] = tokenId;
            }
        }

        assembly {
            mstore(results, count)
        }

        return results;
    }

    /// @notice Check if a token ID is eligible for free mint
    /// @param tokenId Token ID to check
    /// @return True if token is eligible
    function isTokenIdEligible(uint256 tokenId) public view returns (bool) {
        return eligibleTokenIds.contains(tokenId);
    }

    /// @notice Get the total number of eligible tokens
    /// @return Number of tokens in the eligible set
    function getEligibleTokenIdCount() public view returns (uint256) {
        return eligibleTokenIds.length();
    }

    /// @notice Implements interface support for AccessControl
    /// @dev Required override for AccessControl compatibility
    /// @param interfaceId Interface identifier to check
    /// @return bool True if interface is supported
    function supportsInterface(bytes4 interfaceId) public view override(AccessControl) returns (bool) {
        return super.supportsInterface(interfaceId);
    }
}
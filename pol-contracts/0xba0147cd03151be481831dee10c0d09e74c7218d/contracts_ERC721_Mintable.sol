// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "./contracts_token_ERC721_extensions_IERC721Enumerable.sol";

/**
 * @title Mintable Interface
 * @notice (c) 2023 ViciNFT https://vicinft.com/
 * @author Josh Davis <josh.davis@vicinft.com>
 *
 * @dev This interface extends IERC721Enumerable by defining public minting 
 * functions.
 */
interface Mintable is IERC721Enumerable {
    /**
     * @notice returns the total number of tokens that may be minted.
     */
    function maxSupply() external view returns (uint256);

    /**
     * @notice mints a token into `toAddress`.
     * @dev This SHOULD revert if it would exceed maxSupply.
     * @dev This SHOULD revert if `toAddress` is 0.
     * @dev This SHOULD revert if `tokenId` already exists.
     *
     * @param dropName Type, group, option name etc. used or ignored by token manager.
     * @param toAddress The account to receive the newly minted token.
     * @param tokenId The id of the new token.
     */
    function mint(
        bytes32 dropName,
        address toAddress,
        uint256 tokenId
    ) external;

    /**
     * @notice mints a token into `toAddress`.
     * @dev This SHOULD revert if it would exceed maxSupply.
     * @dev This SHOULD revert if `toAddress` is 0.
     * @dev This SHOULD revert if `tokenId` already exists.
     *
     * @param dropName Type, group, option name etc. used or ignored by token manager.
     * @param toAddress The account to receive the newly minted token.
     * @param tokenId The id of the new token.
     * @param customURI the custom URI.
     */
    function mintCustom(
        bytes32 dropName,
        address toAddress,
        uint256 tokenId,
        string memory customURI
    ) external;

    /**
     * @notice mint several tokens into `toAddresses`.
     * @dev This SHOULD revert if it would exceed maxSupply
     * @dev This SHOULD revert if any `toAddresses` are 0.
     * @dev This SHOULD revert if any`tokenIds` already exist.
     *
     * @param dropName Type, group, option name etc. used or ignored by token manager.
     * @param toAddresses The accounts to receive the newly minted tokens.
     * @param tokenIds The ids of the new tokens.
     */
    function batchMint(
        bytes32 dropName,
        address[] memory toAddresses,
        uint256[] memory tokenIds
    ) external;

    /**
     * @notice returns true if the token id is already minted.
     */
    function exists(uint256 tokenId) external returns (bool);
}
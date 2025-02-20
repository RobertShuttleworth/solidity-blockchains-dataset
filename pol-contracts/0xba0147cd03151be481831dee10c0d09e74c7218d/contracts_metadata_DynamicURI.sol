// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

/**
 * @title Dynamic URI Interface
 * @notice (c) 2023 ViciNFT https://vicinft.com/
 * @author Josh Davis <josh.davis@vicinft.com>
 * 
 * @dev Simple interface for contracts that can return a URI for an ID.
 */
interface DynamicURI {
    function tokenURI(uint256 tokenId) external view returns (string memory);
}
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.21;

struct TokenMetadata {
    uint seed;
    uint curatedId;
}

interface ITokenMetadataManager {
    function getTokenMetadata(uint256 tokenId) external view returns (TokenMetadata memory);
}
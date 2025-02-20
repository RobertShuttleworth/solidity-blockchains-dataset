pragma solidity ^0.8.25;

interface ICreditStrategyLike {
    function supportsInterface(bytes4 interfaceId) external view returns (bool);
    function addCreditPosition(uint256 tokenId) external returns (bool);
}
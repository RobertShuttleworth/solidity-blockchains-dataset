// @author Daosourced.
// @date December 21st, 2021

pragma solidity ^0.8.0;

import './contracts_maticnetwork_IMintableERC721.sol';

interface IRootRegistry is IMintableERC721 {
    /**
     * @dev Deposits token to Polygon through RootChainManager contract.
     * @param tokenId id of token
     */
    function depositToPolygon(uint256 tokenId) external;

    /**
     * @dev Exit from Polygon through RootChainManager contract.
     *      It withdraws token with records update.
     * @param tokenId id of token
     * @param keys New record keys
     * @param values New record values
     */
    function withdrawFromPolygon(
        bytes calldata inputData,
        uint256 tokenId,
        string[] calldata keys,
        string[] calldata values
    ) external;
}
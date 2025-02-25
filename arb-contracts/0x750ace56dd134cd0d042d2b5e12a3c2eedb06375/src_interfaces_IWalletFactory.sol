// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.28;

import "./src_interfaces_darenft_IFactory.sol";

interface IWalletFactory {
    event WalletCreated(
        address indexed account,
        address indexed nftCollection,
        uint256 tokenId,
        address receiver,
        uint256 chainId
    );

    event CollectionCreated(
        address indexed collection,
        uint256 indexed collectionIndex,
        string  name,
        string  symbol
    );

    function createWalletCollection(
        uint160 collectionIndex,
        string calldata name,
        string calldata symbol,
        address descriptor
    ) external returns (address);

    function create(address nftAddress) external returns (uint256 tokenId, address tba);

    function createFor(address nftAddress, address receiver) external returns (uint256, address);

    function createTBA(address nftAddress, uint256 tokenId, uint256 chainId) external;

    function depositTokens(address token, address walletAddress, uint256 amount) external;
    
    function depositETH(address walletAddress) payable external;

    function getTokenBoundAccount(address nftAddress, uint256 tokenId) external view returns (address account);
}

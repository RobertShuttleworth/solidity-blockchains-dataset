// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./lib_openzeppelin-contracts-upgradeable_lib_openzeppelin-contracts_contracts_token_ERC721_extensions_IERC721Enumerable.sol";

interface IFiat24Account is IERC721Enumerable {
    
    function mintByWallet(address to, uint256 _tokenId) external;

    function exists(uint256 tokenId) external view returns(bool);

    function checkLimit(uint256 tokenId, uint256 amount) external view returns(bool);

    function setNickname(uint256 tokenId, string memory nickname) external;

    function setNftAvatar(string memory url) external;

    function tokenURI(uint256 tokenId) external view returns (string memory);

    enum Status { Na, SoftBlocked, Tourist, Blocked, Closed, Live }

    function status(uint256 tokenId) external view returns (Status);

    function walletProvider(uint256 userTokenID) external view returns (uint256);
}
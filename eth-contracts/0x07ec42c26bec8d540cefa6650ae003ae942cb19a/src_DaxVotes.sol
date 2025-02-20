// SPDX-License-Identifier: MIT
// Compatible with OpenZeppelin Contracts ^5.0.0
pragma solidity ^0.8.22;

import {EIP712} from "./lib_openzeppelin-contracts_contracts_utils_cryptography_EIP712.sol";
import {ERC721} from "./lib_openzeppelin-contracts_contracts_token_ERC721_ERC721.sol";
import {ERC721Burnable} from "./lib_openzeppelin-contracts_contracts_token_ERC721_extensions_ERC721Burnable.sol";
import {ERC721Enumerable} from "./lib_openzeppelin-contracts_contracts_token_ERC721_extensions_ERC721Enumerable.sol";
import {ERC721Pausable} from "./lib_openzeppelin-contracts_contracts_token_ERC721_extensions_ERC721Pausable.sol";
import {ERC721URIStorage} from "./lib_openzeppelin-contracts_contracts_token_ERC721_extensions_ERC721URIStorage.sol";
import {ERC721Votes} from "./lib_openzeppelin-contracts_contracts_token_ERC721_extensions_ERC721Votes.sol";
import {Ownable} from "./lib_openzeppelin-contracts_contracts_access_Ownable.sol";

contract DaxVotes is
    ERC721,
    ERC721Enumerable,
    ERC721URIStorage,
    ERC721Pausable,
    Ownable,
    ERC721Burnable,
    EIP712,
    ERC721Votes
{
    string private _uri;
    uint256 private _nextTokenId;

    constructor(address initialOwner) ERC721("DaxVotes", "DAXV") Ownable(initialOwner) EIP712("DaxVotes", "1") {}

    function clock() public view override returns (uint48) {
        return uint48(block.timestamp);
    }

    function CLOCK_MODE() public pure override returns (string memory) {
        return "mode=timestamp";
    }

    function forceBurn(address from, uint256 tokenId) public onlyOwner {
        _update(address(0), tokenId, from);
    }

    function pause() public onlyOwner {
        _pause();
    }

    function safeMint(address to, string memory uri) public onlyOwner {
        uint256 tokenId = _nextTokenId++;
        _safeMint(to, tokenId);
        _setTokenURI(tokenId, uri);
    }

    function safeMint(address to) public onlyOwner {
        uint256 tokenId = _nextTokenId++;
        _safeMint(to, tokenId);
    }

    function setTokenURI(uint256 tokenId, string memory uri) public onlyOwner {
        _setTokenURI(tokenId, uri);
    }

    function supportsInterface(bytes4 interfaceId)
        public
        view
        override(ERC721, ERC721Enumerable, ERC721URIStorage)
        returns (bool)
    {
        return super.supportsInterface(interfaceId);
    }

    function tokenURI(uint256 tokenId) public view override(ERC721, ERC721URIStorage) returns (string memory) {
        return super.tokenURI(tokenId);
    }

    function unpause() public onlyOwner {
        _unpause();
    }

    function _baseURI() internal pure override returns (string memory) {
        return "https://daxchain.io/tokens/daxv/";
    }

    function _increaseBalance(address account, uint128 value)
        internal
        override(ERC721, ERC721Enumerable, ERC721Votes)
    {
        super._increaseBalance(account, value);
    }

    function _update(address to, uint256 tokenId, address auth)
        internal
        override(ERC721, ERC721Enumerable, ERC721Pausable, ERC721Votes)
        returns (address)
    {
        return super._update(to, tokenId, auth);
    }
}
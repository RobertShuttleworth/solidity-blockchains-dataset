// SPDX-License-Identifier: MIT
// Compatible with OpenZeppelin Contracts ^5.0.0
pragma solidity ^0.8.20;

import "./openzeppelin_contracts_token_ERC721_ERC721.sol";
import "./openzeppelin_contracts_token_ERC721_extensions_ERC721URIStorage.sol";
import "./openzeppelin_contracts_access_Ownable.sol";

contract BeepBeepNFT is ERC721, ERC721URIStorage, Ownable {
    constructor() ERC721("BeepBeep", "BB") Ownable(_msgSender()) {
        _operator = _msgSender();
    }

    string private _url = "https://beepbeepplanet.com/beep-nft/base/detail/";

    function setURI(string memory newuri) public onlyOperator {
        _url = newuri;
    }

    address private _operator;

    function operator() public view returns (address) {
        return _operator;
    }

    function updateOperator(address _add) public onlyOwner returns (bool) {
        _operator = _add;
        return true;
    }

    error OwnableInvalidOperator(address operator);
    error ArraysLengthNotEqual(uint a, uint b);

    modifier onlyOperator() {
        address _sender = _msgSender();
        if (_sender != _operator) {
            revert OwnableInvalidOperator(_sender);
        }
        _;
    }

    function _baseURI() internal view override returns (string memory) {
        return _url;
    }

    function safeMint(
        address to,
        uint256 tokenId,
        string memory uri
    ) public onlyOperator {
        _safeMint(to, tokenId);
        _setTokenURI(tokenId, uri);
    }

    function mintBatch(
        address to,
        uint256[] memory ids,
        string[] memory uris
    ) public onlyOperator {
        if (ids.length != uris.length) {
            revert ArraysLengthNotEqual(ids.length, uris.length);
        }
        for (uint i = 0; i < ids.length; i++) {
            safeMint(to, ids[i], uris[i]);
        }
    }

    function safeTransferFromBatch(
        address from,
        address to,
        uint256[] memory ids
    ) external {
        for (uint i = 0; i < ids.length; i++) {
            safeTransferFrom(from, to, ids[i]);
        }
    }

    function safeTransFromBatchPlayers(
        address[] memory tos,
        uint256[] memory ids
    ) external {
        if (tos.length != tos.length) {
            revert ArraysLengthNotEqual(tos.length, tos.length);
        }
        address sender = _msgSender();
        for (uint i = 0; i < tos.length; i++) {
            safeTransferFrom(sender, tos[i], ids[i]);
        }
    }

    function tokenURI(
        uint256 tokenId
    ) public view override(ERC721, ERC721URIStorage) returns (string memory) {
        return super.tokenURI(tokenId);
    }

    function supportsInterface(
        bytes4 interfaceId
    ) public view override(ERC721, ERC721URIStorage) returns (bool) {
        return super.supportsInterface(interfaceId);
    }
}
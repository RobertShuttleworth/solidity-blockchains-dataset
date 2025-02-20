// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import {AppStorageRoot, Gotchi} from "./src_AppStorage.sol";
import {AppModifiers} from "./src_AppModifiers.sol";
import {GotchiLibrary} from "./src_libraries_GotchiLibrary.sol";
import {IERC721} from "./lib_openzeppelin-contracts_contracts_token_ERC721_IERC721.sol";
import {IERC721Metadata} from "./lib_openzeppelin-contracts_contracts_token_ERC721_extensions_IERC721Metadata.sol";

/**
 * @title GotchiNFTFacet
 * @notice Handles NFT-specific functionality for Gotchis
 * @dev Implements ERC721 standard within Diamond pattern
 */
contract GotchiNFTFacet is AppModifiers, IERC721, IERC721Metadata {
    event GotchiMinted(address indexed owner, uint256 indexed tokenId);
    
    error MaxSupplyReached();
    error MintingPaused();
    error DeadGotchiNotTransferable();
    error InvalidTokenId();
    error NotTokenOwner();
    error ZeroAddress();

    function mint() external returns (uint256) {
        uint256 tokenId = s.nextTokenId++;
        
        GotchiLibrary.initGotchi(tokenId);
        s.tokenIdToGotchi[tokenId].owner = msg.sender;
        
        emit GotchiMinted(msg.sender, tokenId);
        emit Transfer(address(0), msg.sender, tokenId);
        
        return tokenId;
    }

    function burn(uint256 _tokenId) external {
        address owner = s.tokenIdToGotchi[_tokenId].owner;
        if (msg.sender != owner) {
            revert NotTokenOwner();
        }
        
        delete s.tokenIdToGotchi[_tokenId];
        delete s.tokenApprovals[_tokenId];
        emit Transfer(owner, address(0), _tokenId);
    }

    function getOwnedTokenIds(address owner) external view returns (uint256[] memory) {
        if (owner == address(0)) revert ZeroAddress();
        return GotchiLibrary.getTokenIdsForOwner(owner);
    }

    // ERC721 Implementation
    function balanceOf(address owner) external view returns (uint256) {
        if (owner == address(0)) revert ZeroAddress();
        uint256 balance = 0;
        for (uint256 i = 0; i < s.nextTokenId; i++) {
            if (s.tokenIdToGotchi[i].owner == owner) {
                balance++;
            }
        }
        return balance;
    }

    function ownerOf(uint256 _tokenId) external view returns (address) {
        address owner = s.tokenIdToGotchi[_tokenId].owner;
        if (owner == address(0)) revert InvalidTokenId();
        return owner;
    }

    function approve(address to, uint256 tokenId) external {
        address owner = s.tokenIdToGotchi[tokenId].owner;
        if (msg.sender != owner && !isApprovedForAll(owner, msg.sender)) {
            revert NotTokenOwner();
        }
        s.tokenApprovals[tokenId] = to;
        emit Approval(owner, to, tokenId);
    }

    function getApproved(uint256 tokenId) external view returns (address) {
        if (s.tokenIdToGotchi[tokenId].owner == address(0)) {
            revert InvalidTokenId();
        }
        return s.tokenApprovals[tokenId];
    }

    function setApprovalForAll(address operator, bool approved) external {
        s.operatorApprovals[msg.sender][operator] = approved;
        emit ApprovalForAll(msg.sender, operator, approved);
    }

    function isApprovedForAll(address owner, address operator) public view returns (bool) {
        return s.operatorApprovals[owner][operator];
    }

    function transferFrom(address from, address to, uint256 tokenId) public {
        if (to == address(0)) revert ZeroAddress();
        
        // Check if Gotchi is alive
        if (s.tokenIdToGotchi[tokenId].isDead) {
            revert DeadGotchiNotTransferable();
        }

        // Check ownership and approval
        if (!_isApprovedOrOwner(msg.sender, tokenId)) {
            revert NotTokenOwner();
        }

        // Update ownership
        s.tokenIdToGotchi[tokenId].owner = to;
        delete s.tokenApprovals[tokenId];
        
        emit Transfer(from, to, tokenId);
    }

    function safeTransferFrom(address from, address to, uint256 tokenId) external {
        transferFrom(from, to, tokenId);
    }

    function safeTransferFrom(address from, address to, uint256 tokenId, bytes calldata data) external {
        transferFrom(from, to, tokenId);
    }

    function name() external pure returns (string memory) {
        return "Gotchi";
    }

    function symbol() external pure returns (string memory) {
        return "GTCHI";
    }

    function tokenURI(uint256 _tokenId) external view returns (string memory) {
        if (s.tokenIdToGotchi[_tokenId].owner == address(0)) {
            revert InvalidTokenId();
        }
        return string(abi.encodePacked(s.baseURI, _tokenId));
    }

    function supportsInterface(bytes4 interfaceId) external pure returns (bool) {
        return
            interfaceId == type(IERC721).interfaceId ||
            interfaceId == type(IERC721Metadata).interfaceId;
    }

    // Admin functions
    function setBaseURI(string calldata _baseURI) external onlyOwner {
        s.baseURI = _baseURI;
    }

    // Internal helper at the end
    function _isApprovedOrOwner(address spender, uint256 tokenId) internal view returns (bool) {
        address owner = s.tokenIdToGotchi[tokenId].owner;
        return (spender == owner || 
                this.getApproved(tokenId) == spender || 
                isApprovedForAll(owner, spender));
    }
}
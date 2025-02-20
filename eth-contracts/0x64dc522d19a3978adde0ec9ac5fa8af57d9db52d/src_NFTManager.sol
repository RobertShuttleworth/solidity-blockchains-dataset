// SPDX-License-Identifier: MIT
pragma solidity ^0.8.21;

/*

┌──────────────────────────────────────────────────────────────────┐
│ ███████████    ███████      █████████  ██████   ██████  ████████ │
│░░███░░░░░░█  ███░░░░░███   ███░░░░░███░░██████ ██████  ███░░░░███│
│ ░███   █ ░  ███     ░░███ ███     ░░░  ░███░█████░███ ░░░    ░███│
│ ░███████   ░███      ░███░███          ░███░░███ ░███    ██████░ │
│ ░███░░░█   ░███      ░███░███          ░███ ░░░  ░███   ░░░░░░███│
│ ░███  ░    ░░███     ███ ░░███     ███ ░███      ░███  ███   ░███│
│ █████       ░░░███████░   ░░█████████  █████     █████░░████████ │
│░░░░░          ░░░░░░░      ░░░░░░░░░  ░░░░░     ░░░░░  ░░░░░░░░  │
└──────────────────────────────────────────────────────────────────┘

by Eto Vass (https://x.com/etovass)

*/


import { ERC721A } from "./src_ERC721A_ERC721A.sol";
import { IERC721A } from "./src_ERC721A_IERC721A.sol";
import { ERC721AQueryable } from "./src_ERC721A_extensions_ERC721AQueryable.sol";
import "./node_modules_openzeppelin_contracts_utils_Pausable.sol";
import "./node_modules_openzeppelin_contracts_access_Ownable.sol";
import "./node_modules_openzeppelin_contracts_token_common_ERC2981.sol";

import { IGameRenderer } from './src_interfaces_IGameRenderer.sol';
import { Utils } from './src_common_Utils.sol';
import { CuratedManager } from './src_curated_CuratedManager.sol';

import { ITokenMetadataManager, TokenMetadata } from './src_interfaces_ITokenMetadataManager.sol';

import { console2 } from "./lib_forge-std_src_console2.sol";

contract NFTManager is ERC721A, ERC2981, ERC721AQueryable, Pausable, Ownable, CuratedManager, ITokenMetadataManager {

    uint public constant MAX_NFT_ITEMS = 300;           // no more than 400, due to the curated puzzles
    uint public constant MAX_TOKENS_PER_ADDRESS = 10;    
    uint public pricePerMint = 0.02 ether;

    bool public mintingIsOpen = true;

    IGameRenderer public gameRenderer;

    uint public seedNonce;
    uint public rndSeed;
    
    mapping(uint => TokenMetadata) public tokenMetadata; 

    constructor(uint _reservedForEto, uint _pricePerMint) ERC721A("FOCM3", "FOCM3") Ownable(msg.sender) {
        pricePerMint = _pricePerMint;

        rndSeed = uint(blockhash(block.number - 1));

        console2.log("rndSeed", rndSeed);

        if (_reservedForEto > 0) {
            _safeMint(msg.sender, _reservedForEto);                // reserve first few for the author

            for(uint256 tokenId = 0; tokenId < _reservedForEto; tokenId++) {
                _saveNewSeed(tokenId);
            }
        }
        _setDefaultRoyalty(msg.sender, _feeDenominator() / 20); // 5% royalty, unfortunately this is not enforced by marketplaces
    }

    function setGameRenderer(IGameRenderer _gameRenderer) public onlyOwner {
        gameRenderer = _gameRenderer;
    }

    function _getCuratedSeed(uint tokenId) internal returns (int) {
        rndSeed = uint256(keccak256(abi.encode(rndSeed, blockhash(block.number - 1), tokenId, msg.sender)));
        return getRandomCuratedToken(rndSeed);
    }

    function _saveNewSeed(uint tokenId) internal {
        tokenMetadata[tokenId] = TokenMetadata({
            seed: uint256(keccak256(abi.encode(seedNonce, blockhash(block.number - 1), tokenId, msg.sender))),
            curatedId: uint(_getCuratedSeed(tokenId))
        });
    }

    function _getTokenMetadata(uint256 tokenId) internal view returns (TokenMetadata memory) {
        return tokenMetadata[tokenId];
    }

    function getTokenMetadata(uint256 tokenId) external view tokenExists(tokenId) returns (TokenMetadata memory) {
        return _getTokenMetadata(tokenId);
    }

    function pause() public onlyOwner {
        _pause();
    }

    function unpause() public onlyOwner {
        _unpause();
    }

    function isMintOpen() public view returns (bool) {
        return mintingIsOpen;
    }

    function closeMint() public onlyOwner {
        mintingIsOpen = false;
    }

    function setPricePerMint(uint _price) public onlyOwner {
        pricePerMint = _price;
    }

    modifier canMint {
        require(mintingIsOpen, "Mint has ended");
        require(totalSupply() < MAX_NFT_ITEMS, "Mint has ended");
        require(!paused(), "Mint is paused");
        _;
    }

    // Token exists
    modifier tokenExists(uint _tokenId) {
        require(_exists(_tokenId), "URI query for nonexistent token");
        _;
    }

    modifier onlyTokenOwner(uint _tokenId) {
        require(
            ownerOf(_tokenId) == msg.sender,
            "The caller is not the owner of the token"
        );
        _;
    }


    function mint(uint quantity) public canMint payable {
        uint256 total = totalSupply();
        require(total + quantity <= MAX_NFT_ITEMS, "Minted out");
        require(msg.value >= quantity * pricePerMint, "Insufficient funds");
        require(balanceOf(msg.sender) + quantity <= MAX_TOKENS_PER_ADDRESS, "Max mint per address reached");
        
        uint256 startTokenId = total;

        for(uint256 tokenId = startTokenId; tokenId < startTokenId + quantity; tokenId++) {
            _saveNewSeed(tokenId);
        }
        _safeMint(msg.sender, quantity);
    }

    function tokenURI(uint tokenId) public view override(IERC721A, ERC721A) tokenExists(tokenId) returns (string memory) {
        return gameRenderer.tokenURI(tokenId);
    }

    function tokenHTML(uint tokenId) public view tokenExists(tokenId) returns (string memory) {
        return gameRenderer.tokenHTML(tokenId);
    }

    function tokenImage(uint tokenId) public view tokenExists(tokenId) returns (string memory) {
        return gameRenderer.tokenImage(tokenId);
    }

    function tokenTraits(uint tokenId) public view tokenExists(tokenId) returns (string memory) {
        return gameRenderer.tokenTraits(tokenId);
    }

    function withdraw(address payable recipient, uint256 amount) public onlyOwner {
        require(recipient != address(0), 'Recipient address can not be address zero');

        uint balance = address(this).balance;
        require(balance > 0, "Nothing left to withdraw");

        (bool succeed, ) = recipient.call{value: amount}("");
        require(succeed, "Failed to withdraw");
    }

    function withdrawAll() public onlyOwner {
        uint balance = address(this).balance;
        payable(msg.sender).transfer(balance);
    }

    receive() external payable {}

    function supportsInterface(bytes4 interfaceId) public view virtual override(IERC721A, ERC721A, ERC2981) returns (bool) {
        return ERC721A.supportsInterface(interfaceId) || ERC2981.supportsInterface(interfaceId);
    }
}
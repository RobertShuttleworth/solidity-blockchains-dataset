// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./openzeppelin_contracts-upgradeable_token_ERC721_ERC721Upgradeable.sol";
import "./openzeppelin_contracts-upgradeable_access_OwnableUpgradeable.sol";
import "./openzeppelin_contracts-upgradeable_proxy_utils_Initializable.sol";
import "./openzeppelin_contracts-upgradeable_utils_PausableUpgradeable.sol";
import "./openzeppelin_contracts-upgradeable_utils_ReentrancyGuardUpgradeable.sol";
import "./openzeppelin_contracts_utils_StorageSlot.sol";

contract Artequity_CollectionERC721_NFT is 
    Initializable, 
    ERC721Upgradeable, 
    OwnableUpgradeable,
    PausableUpgradeable,
    ReentrancyGuardUpgradeable 
{
    using StorageSlot for bytes32;

    // Define a storage slot for the token counter
    bytes32 private constant _TOKEN_ID_SLOT = keccak256("my.nft.tokenid.slot");

    // Events
    event TokenMinted(address indexed to, uint256 indexed tokenId);

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    // Initializer function replaces the constructor for upgradeable contracts
    function initialize() public initializer {
        __ERC721_init("Hashs", "HASHS");
        __Ownable_init(msg.sender);
        __Pausable_init();
        __ReentrancyGuard_init();
    }

    // Function to get the current token ID
    function getCurrentTokenCount() public view returns (uint256) {
        return _TOKEN_ID_SLOT.getUint256Slot().value;
    }

    // Function to mint a new NFT and increment the token ID counter
    // function safeMint(address to) public onlyOwner whenNotPaused nonReentrant returns (uint256) {
    //     require(to != address(0), "Invalid recipient address");
        
    //     // Increment the token ID counter
    //     uint256 newTokenId = getCurrentTokenCount() + 1;
    //     _TOKEN_ID_SLOT.getUint256Slot().value = newTokenId;

    //     // Mint the NFT
    //     _safeMint(to, newTokenId);
    //     emit TokenMinted(to, newTokenId);
    //     return newTokenId;
    // }

    // Function to mint an NFT with a specific token ID
    function safeMintWithId(address to, uint256 tokenId) 
        public 
        whenNotPaused 
        nonReentrant 
    {
        require(to != address(0), "Invalid recipient address");
        _safeMint(to, tokenId);
        emit TokenMinted(to, tokenId);
    }

    // Pause function
    function pause() public onlyOwner {
        _pause();
    }

    // Unpause function
    function unpause() public onlyOwner {
        _unpause();
    }

    // Override transferOwnership to call _transferOwnership
    function transferOwnership(address newOwner) public override onlyOwner {
        require(newOwner != address(0), "New owner cannot be zero address");
        _transferOwnership(newOwner);
    }

    // Override supportsInterface to support ERC721
    function supportsInterface(bytes4 interfaceId)
        public
        view
        override(ERC721Upgradeable)
        returns (bool)
    {
        return super.supportsInterface(interfaceId);
    }
}
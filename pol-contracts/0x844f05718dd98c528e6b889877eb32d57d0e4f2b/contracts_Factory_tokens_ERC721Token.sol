// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.16;

import "./openzeppelin_contracts-upgradeable_proxy_utils_Initializable.sol";
import "./openzeppelin_contracts-upgradeable_proxy_utils_UUPSUpgradeable.sol";
import "./openzeppelin_contracts-upgradeable_token_ERC721_ERC721Upgradeable.sol";
import "./openzeppelin_contracts-upgradeable_token_ERC721_extensions_ERC721URIStorageUpgradeable.sol";
import "./openzeppelin_contracts-upgradeable_security_PausableUpgradeable.sol";
import "./openzeppelin_contracts-upgradeable_access_OwnableUpgradeable.sol";
import "./openzeppelin_contracts-upgradeable_token_ERC721_extensions_ERC721BurnableUpgradeable.sol";
import "./openzeppelin_contracts-upgradeable_utils_CountersUpgradeable.sol";
import "./openzeppelin_contracts-upgradeable_security_ReentrancyGuardUpgradeable.sol";
import "./openzeppelin_contracts-upgradeable_token_ERC721_extensions_ERC721EnumerableUpgradeable.sol";
import "./openzeppelin_contracts-upgradeable_token_common_ERC2981Upgradeable.sol";
import "./contracts_Factory_MarketplaceFactory.sol";

contract ERC721Token is
    Initializable,
    UUPSUpgradeable,
    ERC721Upgradeable,
    ERC721URIStorageUpgradeable,
    ERC721BurnableUpgradeable,
    OwnableUpgradeable,
    PausableUpgradeable,
    ReentrancyGuardUpgradeable,
    ERC721EnumerableUpgradeable,
    ERC2981Upgradeable
{
    using CountersUpgradeable for CountersUpgradeable.Counter;

    CountersUpgradeable.Counter private _tokenIdCounter;

    string public description;

    mapping(uint256 => address) public creator; // maps the tokenId with creator wallet address

    uint256 public platformFee; // platform fee for minting NFT's
    uint96 public royaltyFee; // royalty fee percentage

    address public factory; // address of nft collection creating factory
    address public admin; // admin who sets the platform fee
    address public currentRoyaltyReceiver; //royalty receiver
    address public paymentSplitter; // payment splitter contract address

    event SetPlatformFee(uint256 fee, address indexed owner);
    event RoyaltyFeeUpdated(address indexed owner, uint96 newRoyaltyFee);
    event RoyaltyReceiverUpdated(address indexed newRoyaltyReceiver);
    event DestroyCollection(address indexed collection);

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() initializer {}

    /**
     * @dev Initializes the contract.
     *
     * @param collectionName.
     * @param collectionSymbol.
     * @param collectionDescription.
     * @param _feeNumerator royalty fee
     * @param _platformFee platform fee
     * @param _admin admin wallet address
     * @param _factory address of nft collection creating factory
     * @param _paymentSplitter payment splitter contract address
     */
    function initialize(
        string memory collectionName,
        string memory collectionSymbol,
        string memory collectionDescription,
        uint96 _feeNumerator,
        uint256 _platformFee,
        address _admin,
        address _factory,
        address _paymentSplitter
    ) external initializer {
        __ERC721_init_unchained(collectionName, collectionSymbol);
        __Ownable_init_unchained();
        __Pausable_init_unchained();
        __ReentrancyGuard_init_unchained();
        __ERC2981_init_unchained();
        _setDefaultRoyalty(_paymentSplitter, _feeNumerator);
        description = collectionDescription;
        currentRoyaltyReceiver = _paymentSplitter;
        admin = _admin;
        factory = _factory;
        royaltyFee = _feeNumerator;
        platformFee = _platformFee;
        paymentSplitter = _paymentSplitter;
    }

    /**
     * @dev modifier checks whether the caller is admin wallet address
     */
    modifier onlyAdmin() {
        require(msg.sender == admin, "Caller is not the admin");
        _;
    }

    /**
     * @dev returns the token ID of the next NFT that will be minted
     */
    function getNextMintableToken() public view returns (uint256) {
        return _tokenIdCounter.current();
    }

    /**
     * @dev Returns the token uri of particular token id
     * @param tokenId.
     */
    function tokenURI(
        uint256 tokenId
    )
        public
        view
        override(ERC721Upgradeable, ERC721URIStorageUpgradeable)
        returns (string memory)
    {
        return super.tokenURI(tokenId);
    }

    /**
     * @dev Sets the new royalty receiver
     * @param _receiver.
     *
     * Emits {RoyaltyReceiverUpdated} event.
     */
    function setRoyaltyReceiver(
        address _receiver
    ) external onlyOwner whenNotPaused {
        currentRoyaltyReceiver = _receiver;
        _setDefaultRoyalty(currentRoyaltyReceiver, royaltyFee);
        emit RoyaltyReceiverUpdated(_receiver);
    }

    /**
     * @dev Sets new royalty fee percentage
     * @param _newFee.
     *
     * Emits {RoyaltyFeeUpdated} event
     *
     * Requirements:
     *
     * - Caller must be the owner of this contract
     * - `_newFee` must be greater than zero
     */
    function setRoyaltyFee(uint96 _newFee) external onlyAdmin whenNotPaused {
        require(_newFee > 0, "Royalty Fee should not be zero.");
        royaltyFee = _newFee;
        _setDefaultRoyalty(currentRoyaltyReceiver, royaltyFee);
        emit RoyaltyFeeUpdated(msg.sender, _newFee);
    }

    /**
     * @dev Sets `_tokenURI` as the new tokenURI of `tokenId`.
     * @param tokenId.
     * @param _tokenURI.
     *
     * Requirements:
     *
     * - The caller must own `tokenId` or be the creator of token id
     * - `tokenId` must exist.
     */
    function updateTokenUri(
        uint256 tokenId,
        string memory _tokenURI
    ) external whenNotPaused {
        require(
            msg.sender == admin ||
                msg.sender == owner() ||
                msg.sender == ownerOf(tokenId),
            "Caller is not the admin or collection owner or nft owner"
        );
        _setTokenURI(tokenId, _tokenURI);
    }

    /**
     * @dev Sets `description` for collection.
     * @param _description.
     *
     * Requirements:
     *
     * - The caller must be admin or owner.
     */
    function updateCollectionDescription(
        string memory _description
    ) external whenNotPaused {
        require(
            msg.sender == admin || msg.sender == owner(),
            "Caller is not the admin or owner"
        );
        description = _description;
    }

    /**
     * @dev Sets new platform fee
     * @param _newPlatformFee.
     *
     * Emits {SetPlatformFee} event
     *
     * Requirements:
     *
     * - Caller must be the admin account
     */
    function setPlatformFee(
        uint256 _newPlatformFee
    ) external onlyAdmin whenNotPaused {
        platformFee = _newPlatformFee;
        emit SetPlatformFee(_newPlatformFee, msg.sender);
    }

    /**
     * @dev Mint single nft with ONLY OWNER
     * @param to - account
     * @param uri - token uri
     */
    function safeMint(
        address to,
        string memory uri
    ) external payable onlyOwner whenNotPaused nonReentrant {
        require(msg.value >= platformFee, "Not enough ether sent for minting fee.");
        // transfer minting fee to collection owner
        payable(admin).transfer(msg.value);
        uint256 tokenId = _tokenIdCounter.current();
        _tokenIdCounter.increment();
        creator[tokenId] = msg.sender;
        _safeMint(to, tokenId);
        _setTokenURI(tokenId, uri);
    }

    /**
     * @dev Mint multiple nft with ONLY OWNER
     * @param to - account
     * @param uris - token uris
     */
    function safeMintBatch(
        address to,
        string[] memory uris
    ) external payable onlyOwner whenNotPaused nonReentrant {
        require(msg.value >= platformFee * uris.length, "Not enough ether sent for minting fee.");
        // transfer minting fee to collection owner
        payable(admin).transfer(msg.value);
        for (uint256 i = 0; i < uris.length; i++) {
            uint256 tokenId = _tokenIdCounter.current();
            _tokenIdCounter.increment();
            creator[tokenId] = msg.sender;
            _safeMint(to, tokenId);
            _setTokenURI(tokenId, uris[i]);
        }
    }

    /**
     * @dev Burns `tokenId`. See {ERC721-_burn}.
     *
     * Requirements:
     *
     * - The caller must own `tokenId` or be an approved operator or be the creator of token id
     */
    function burn(uint256 tokenId) public virtual override {
        require(
            msg.sender == admin ||
                msg.sender == ERC721Upgradeable.ownerOf(tokenId) ||
                msg.sender == owner(),
            "Unauthorized: Caller does not have permission."
        );
        _burn(tokenId);
    }

    /**
     * @dev Pause the contract (stopped state)
     * by caller with ONLY OWNER.
     *
     * - The contract must not be paused.
     *
     * Emits a {Paused} event.
     */
    function pause() external onlyOwner {
        _pause();
    }

    /**
     * @dev Unpause the contract (normal state)
     * by caller with ONLY OWNER.
     *
     * - The contract must be paused.
     *
     * Emits a {Unpaused} event.
     */
    function unpause() external onlyOwner {
        _unpause();
    }

    /**
     * @dev Returns true if this contract implements the interface defined by `interfaceId`.
     *
     * This function call must use less than 30 000 gas.
     */
    function supportsInterface(
        bytes4 interfaceId
    )
        public
        view
        virtual
        override(
            ERC721Upgradeable,
            ERC721EnumerableUpgradeable,
            ERC2981Upgradeable,
            ERC721URIStorageUpgradeable
        )
        returns (bool)
    {
        return super.supportsInterface(interfaceId);
    }

    /**
     * @dev Function that should revert when `msg.sender` is not authorized to upgrade the contract. Called by
     * {upgradeTo} and {upgradeToAndCall}
     */
    function _authorizeUpgrade(address) internal override onlyOwner {}

    /**
     * @dev Destroys `tokenId`.
     * The approval is cleared when the token is burned.
     *
     * Requirements:
     *
     * - `tokenId` must exist.
     *
     * Emits a {Transfer} event.
     */
    function _burn(
        uint256 tokenId
    ) internal override(ERC721Upgradeable, ERC721URIStorageUpgradeable) {
        super._burn(tokenId);
    }

    /**
     * @dev Hook that is called before any token transfer. This includes minting and burning.
     *
     * Calling conditions:
     *
     * - When `from` and `to` are both non-zero, ``from``'s tokens will be transferred to `to`.
     * - When `from` is zero, the tokens will be minted for `to`.
     * - When `to` is zero, ``from``'s tokens will be burned.
     * - `from` and `to` are never both zero.
     * - `batchSize` is non-zero.
     */
    function _beforeTokenTransfer(
        address from,
        address to,
        uint256 tokenId,
        uint256 batchSize
    )
        internal
        override(ERC721Upgradeable, ERC721EnumerableUpgradeable)
        whenNotPaused
    {
        super._beforeTokenTransfer(from, to, tokenId, batchSize);
    }

    /**
     * @dev Destroys the collection
     *
     * Emits {DestroyCollection} event.
     *
     * Requirements:
     * - Caller must be the admin of this collection
     */
    /// @custom:oz-upgrades-unsafe-allow selfdestruct
    function destroyCollection() public onlyAdmin {
        MarketplaceFactory(factory).setCollectionIsDestroyed(address(this));
        emit DestroyCollection(address(this));
        selfdestruct(payable(owner()));
    }

    /**
     * @dev Overriding renounce ownership as functionality not needed
     */
    function renounceOwnership()
        public
        virtual
        override
        onlyOwner
        whenNotPaused
    {}
}
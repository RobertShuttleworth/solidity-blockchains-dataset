// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.16;

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
import "./contracts_Factory_MarketplaceFactoryV2.sol";
import "./openzeppelin_contracts-upgradeable_utils_cryptography_draft-EIP712Upgradeable.sol";
import "./openzeppelin_contracts-upgradeable_utils_cryptography_ECDSAUpgradeable.sol";
import "./openzeppelin_contracts-upgradeable_token_ERC20_utils_SafeERC20Upgradeable.sol";
import "./openzeppelin_contracts-upgradeable_token_ERC20_IERC20Upgradeable.sol";
import "./openzeppelin_contracts-upgradeable_interfaces_IERC2981Upgradeable.sol";
import "./openzeppelin_contracts-upgradeable_token_ERC20_extensions_IERC20MetadataUpgradeable.sol";

contract LazyMintERC721TokenV2 is
    Initializable,
    UUPSUpgradeable,
    ERC721Upgradeable,
    ERC721URIStorageUpgradeable,
    ERC721BurnableUpgradeable,
    OwnableUpgradeable,
    PausableUpgradeable,
    ReentrancyGuardUpgradeable,
    ERC721EnumerableUpgradeable,
    ERC2981Upgradeable,
    EIP712Upgradeable
{
    using SafeERC20Upgradeable for IERC20Upgradeable;

    using CountersUpgradeable for CountersUpgradeable.Counter;

    CountersUpgradeable.Counter private _tokenIdCounter;

    string public description;

    string private constant SIGNING_DOMAIN = "Voucher-Domain";
    string private constant SIGNATURE_VERSION = "1";
    address public minter;

    struct LazyNFTVoucher {
        uint256 tokenId;
        uint256 price;
        string uri;
        address buyer;
        bytes signature;
        address currencyAddress;
        address seller;
    }

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
    event LazyMint(
        address collection,
        address indexed buyer,
        address indexed seller,
        uint256 indexed tokenId,
        uint256 price
    );

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
        address _paymentSplitter,
        address _minter
    ) external initializer {
        __EIP712_init(SIGNING_DOMAIN, SIGNATURE_VERSION);
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
        minter = _minter;
    }

    /**
     * @dev modifier checks whether the caller is admin wallet address
     */
    modifier onlyAdmin() {
        require(msg.sender == admin, "Not Admin");
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
        require(_newFee > 0, "fee must be > 0");
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
            "Not Admin"
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
            "Not Admin"
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

    // Function to recover the signer of a LazyNFT voucher
    function recover(
        LazyNFTVoucher calldata voucher
    ) public view returns (address) {
        bytes32 digest = _hashTypedDataV4(
            keccak256(
                abi.encode(
                    keccak256(
                        "LazyNFTVoucher(uint256 tokenId,uint256 price,string uri,address buyer,address currencyAddress,address seller)"
                    ),
                    voucher.tokenId,
                    voucher.price,
                    keccak256(bytes(voucher.uri)),
                    voucher.buyer,
                    voucher.currencyAddress,
                    voucher.seller
                )
            )
        );
        address signer = ECDSAUpgradeable.recover(digest, voucher.signature);
        return signer;
    }

    /**
     * @dev Mints an NFT based on the provided voucher.
     * @param voucher The data structure containing necessary information for minting.
     *
     * Requirements:
     * - The signature of the voucher must match the minter's address.
     * - Sufficient Ether must be sent for the purchase, covering the platform fee.
     * - The minting fee is transferred to the collection owner.
     * - The creator of the token is set to the buyer's address.
     * - The NFT is minted to the buyer's address with the specified token ID.
     * - The token URI for metadata is set based on the voucher information.
     * - Emits a `LazyMint` event with relevant information.
     * - Transfers royalty to the designated receiver based on ERC-2981 standard.
     * - Transfers the purchase amount to the seller after deducting the royalty.
     *
     * Emits a {LazyMint} event on successful NFT minting.
     */
    function safeMint(LazyNFTVoucher calldata voucher) public payable {
        uint256 tokenId = _tokenIdCounter.current();
        _tokenIdCounter.increment();

        require(tokenId == voucher.tokenId, "Token ID mismatch.");
        // Verify the signature of the voucher matches the minter's address
        require(minter == recover(voucher), "Wrong signature.");
        // Verify that enough ether has been sent for the purchase
        require(
            msg.value >= platformFee,
            "Insufficient ether."
        );

        // transfer minting fee to collection owner
        payable(admin).transfer(msg.value);

        // calculate the total price to be paid by the buyer
        uint256 buyerFee = calculateLazyMintBuyerFee(voucher.price, IERC20MetadataUpgradeable(voucher.currencyAddress));
        uint256 totalPrice = voucher.price + buyerFee;

        // Set the creator of the token
        creator[voucher.tokenId] = voucher.buyer;
        // Mint the new NFT to the buyer's address
        _safeMint(voucher.buyer, voucher.tokenId);
        // Set the token URI for metadata
        _setTokenURI(voucher.tokenId, voucher.uri);
        emit LazyMint(
            address(this),
            voucher.buyer,
            voucher.seller,
            voucher.tokenId,
            voucher.price
        );

        // Transfer royalty
        (address receiver, uint256 royaltyAmount) = IERC2981Upgradeable(
            address(this)
        ).royaltyInfo(voucher.tokenId, voucher.price);

        IERC20Upgradeable(voucher.currencyAddress).safeTransferFrom(
            msg.sender,
            receiver,
            royaltyAmount
        );

        // Transfer Buyer fee
        if(buyerFee > 0 || MarketplaceFactoryV2(factory).lazyMintERC721FeeCollectorAddress() != address(0)){
            IERC20Upgradeable(voucher.currencyAddress).safeTransferFrom(
            msg.sender,
            MarketplaceFactoryV2(factory).lazyMintERC721FeeCollectorAddress(),
            buyerFee
        );
        } 

        // Transfer amount
        IERC20Upgradeable(voucher.currencyAddress).safeTransferFrom(
            msg.sender,
            voucher.seller,
            totalPrice - (royaltyAmount + buyerFee)
        );
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
    function destroyCollection() public onlyAdmin {
        MarketplaceFactory(factory).setCollectionIsDestroyed(address(this));
        emit DestroyCollection(address(this));
        selfdestruct(payable(owner()));
    }

    // Function to update the minter address (only callable by the owner)
    function updateMinter(address newMinter) public onlyOwner {
        // Ensure the new minter address is not zero
        require(newMinter != address(0), "Invalid address");
        // Update the minter address
        minter = newMinter;
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

    /**
     * @dev Calculates the buyer fee for lazy minting.
     * @param _price The price of the NFT.
     * @param _currencyAddress The address of the currency used for payment.
     * @return The calculated buyer fee.
     */
    function calculateLazyMintBuyerFee(uint256 _price, IERC20MetadataUpgradeable _currencyAddress)
        public
        view
        returns (uint256)
    {
        uint256 lazyMintBuyerFeePercentage = MarketplaceFactoryV2(factory).lazyMintERC721BuyerFeePercentage();
        // Fixed fee amount for lazy minting in the specified currency
        uint256 lazyMintBuyerFeeFixed = MarketplaceFactoryV2(factory).lazyMintERC721BuyerFeeFixedAmount();
        // Calculate the fixed amount for the buyer fee based on the currency's decimals
        uint256 fixedAmount = (lazyMintBuyerFeeFixed * (10**_currencyAddress.decimals()));
        // Calculate the percentage amount for the buyer fee based on the price
        uint256 percentageAmount = (_price * lazyMintBuyerFeePercentage) / 10000;
        return fixedAmount + percentageAmount;
    }
}
// SPDX-License-Identifier: MIT

pragma solidity ^0.8.13;

import "./openzeppelin_contracts_utils_Strings.sol";
import "./openzeppelin_contracts_utils_cryptography_MerkleProof.sol";
import {IMicroManager} from "./contracts_interfaces_IMicroManager.sol";
import "./contracts_erc721_Micro3.sol";

error SaleInactive();
error PurchaseWrongPrice(uint256 correctPrice);
error SoldOut();
error PurchaseTooManyForAddress();
error Canceled();
error IsNotBridge();
error SaleCanNotUpdate();
error InvalidSaleDetail();
error SaleIsNotEnded();
error Unauthorized();
error PresaleMerkleNotApproved();

contract MicroSocialNFT is Micro3 {
    using Strings for uint256;
    IMicroManager public microManager;

    uint256 public constant VERSION = 6;
    address public owner;
    string private _baseURL;
    string private _notRevealedURL;
    bool private _initialized;
    uint224 private _currentTokenId;

    struct SaleConfiguration {
        uint64 editionSize;
        uint16 profitSharing;
        address payable fundsRecipient;
        uint256 publicSalePrice;
        uint32 maxSalePurchasePerAddress;
        uint64 publicSaleStart;
        uint64 publicSaleEnd;
        bytes32 presaleMerkleRoot;
        bool cancelable;
    }

    mapping(address => uint256) public totalMintsByAddress;

    SaleConfiguration public saleConfig;

    event CrossMint(
        address indexed _to,
        uint256 _quantity,
        uint256 _srcChainId
    );

    event BridgeIn(address indexed _to, uint256 _dstChainId, uint256 _tokenId);

    event BridgeOut(
        address indexed _from,
        uint256 _dstChainId,
        uint256 _tokenId
    );

    event Purchase(
        address indexed to,
        uint256 indexed quantity,
        uint256 indexed price,
        uint256 firstMintedTokenId
    );

    event OpenMintFinalized(
        address indexed sender,
        uint256 editionSize,
        uint256 timeEnd
    );

    event AddMerkleProof(bytes32 indexed merkle);

    event CancelSaleEdition(address indexed sender, uint256 lastTimeUpdated);

    event PublicSaleCollection(address indexed sender, uint256 lastTimeUpdated);

    event FundsWithdrawn(
        address indexed sender,
        address indexed fundsRecipient,
        uint256 fund
    );

    modifier onlyOwner() {
        require(owner == _msgSender());
        _;
    }

    modifier onlyBridge() {
        if (!microManager.microBridge(_msgSender())) {
            revert IsNotBridge();
        }
        _;
    }

    modifier onlyCancelable() {
        if (saleConfig.cancelable) {
            revert Canceled();
        }
        _;
    }

    modifier canMintTokens(uint256 quantity) {
        if (
            saleConfig.editionSize != 0 &&
            quantity + _currentTokenId > saleConfig.editionSize
        ) {
            revert SoldOut();
        }
        _;
    }

    modifier onlyPublicSaleActive() {
        if (
            !(saleConfig.publicSaleStart <= block.timestamp &&
                saleConfig.publicSaleEnd > block.timestamp)
        ) {
            revert SaleInactive();
        }
        _;
    }

    function init(bytes memory initPayload) external returns (bool) {
        if (_initialized) {
            revert Unauthorized();
        }
        (
            string memory _url,
            string memory _singleUrl,
            string memory _name,
            string memory _symbol,
            address _owner,
            address _manager,
            bytes memory _saleConfig
        ) = abi.decode(
                initPayload,
                (string, string, string, string, address, address, bytes)
            );
        owner = _owner;
        _setManager(_manager);
        _baseURL = _url;
        _notRevealedURL = _singleUrl;
        _init(_name, _symbol);
        _initialized = true;
        _setSaleDetail(_saleConfig);
        return true;
    }

    function tokenURI(uint256 tokenId)
        public
        view
        virtual
        override
        returns (string memory)
    {
        _requireOwned(tokenId);

        if (bytes(_notRevealedURL).length > 0) {
            return _notRevealedURL;
        }

        return
            bytes(_baseURL).length > 0
                ? string(
                    abi.encodePacked(_baseURL, uint256(block.chainid).toString(), "/",tokenId.toString(), ".json")
                )
                : "";
    }

    function setBaseURI(string memory _newURI) external onlyOwner {
        _setBaseURI(_newURI);
    }

    function setNotRevealedURI(string memory _newURI) external onlyOwner {
        _notRevealedURL = _newURI;
    }

    /**
     * Owner, Admin FUNCTIONS
     * non state changing
     */

    function transferOwnership(address newOwner) external onlyOwner {
        if (newOwner == address(0)) {
            revert Unauthorized();
        }
        _setOwner(newOwner);
    }

    function setSaleDetail(bytes memory initPayload)
        external
        onlyCancelable
        onlyOwner
    {
        _setSaleDetail(initPayload);
    }

    function setMerkleProof(bytes32 _merkle) external onlyCancelable onlyOwner {
        saleConfig.presaleMerkleRoot = _merkle;
        emit AddMerkleProof(_merkle);
    }

    function finalizeOpenEdition() external onlyCancelable onlyOwner {
        saleConfig.editionSize = uint64(_currentTokenId);
        saleConfig.publicSaleEnd = uint64(block.timestamp);
        emit OpenMintFinalized(
            _msgSender(),
            saleConfig.editionSize,
            block.timestamp
        );
    }

    function cancelSaleEdition() external onlyCancelable onlyOwner {
        if (block.timestamp > saleConfig.publicSaleEnd) {
            revert SaleIsNotEnded();
        }
        saleConfig.cancelable = true;
        emit CancelSaleEdition(_msgSender(), block.timestamp);
    }

    /**
     * EXTERNAL FUNCTIONS
     * state changing
     */
    function purchase(address minter, uint256 quantity)
        external
        onlyCancelable
        canMintTokens(quantity)
        onlyPublicSaleActive
        onlyBridge
        returns (uint256)
    {
        if (saleConfig.presaleMerkleRoot != bytes32(0)) {
            revert Unauthorized();
        }

        _isMinting(minter, quantity);

        emit Purchase({
            to: minter,
            quantity: quantity,
            price: saleConfig.publicSalePrice,
            firstMintedTokenId: _currentTokenId
        });

        return _currentTokenId;
    }

    function purchasePresale(
        address minter,
        uint256 quantity,
        bytes32[] calldata merkleProof
    )
        external
        onlyCancelable
        canMintTokens(quantity)
        onlyPublicSaleActive
        onlyBridge
        returns (uint256)
    {
        if (
            !MerkleProof.verify(
                merkleProof,
                saleConfig.presaleMerkleRoot,
                keccak256(abi.encodePacked(minter))
            )
        ) {
            revert PresaleMerkleNotApproved();
        }

        _isMinting(minter, quantity);

        emit Purchase({
            to: minter,
            quantity: quantity,
            price: saleConfig.publicSalePrice,
            firstMintedTokenId: _currentTokenId
        });

        return _currentTokenId;
    }

    function bridgeOut(
        address _from,
        uint64 _dstChainId,
        uint256 _tokenId
    ) external onlyBridge {
        _burn(_tokenId);
        emit BridgeOut(_from, _dstChainId, _tokenId);
    }

    function bridgeIn(
        address _toAddress,
        uint64 _dstChainId,
        uint256 _tokenId
    ) external onlyBridge {
        _safeMint(_toAddress, _tokenId);
        emit BridgeIn(_toAddress, _dstChainId, _tokenId);
    }

    function crossMint(
        address _toAddress,
        address _fundAddress,
        uint256 _quantity,
        uint256 _priceCheck,
        uint64 _srcChainId
    )
        external
        onlyBridge
        canMintTokens(_quantity)
        onlyCancelable
        onlyPublicSaleActive
    {
        if (saleConfig.fundsRecipient != _fundAddress) {
            revert Unauthorized();
        }

        uint256 totalPurchase = saleConfig.publicSalePrice * _quantity;

        if (_priceCheck < totalPurchase) {
            revert PurchaseWrongPrice(totalPurchase);
        }

        _isMinting(_toAddress, _quantity);

        emit CrossMint(_toAddress, _quantity, _srcChainId);
    }

    /**
     * INTERNAL FUNCTIONS
     * state changing
     */
    function _mintNFTs(address recipient, uint256 quantity) internal {
        for (uint256 i; i < quantity; ) {
            _currentTokenId += 1;
            _safeMint(
                recipient,
                uint256(
                    bytes32(
                        abi.encodePacked(
                            uint32(block.chainid),
                            uint224(_currentTokenId)
                        )
                    )
                )
            );
            unchecked {
                ++i;
            }
        }
    }

    function _isMinting(address toAddress, uint256 quantity) internal {
        if (quantity == 0) {
            revert Unauthorized();
        }

        if (
            saleConfig.maxSalePurchasePerAddress != 0 &&
            totalMintsByAddress[toAddress] + quantity >
            saleConfig.maxSalePurchasePerAddress
        ) {
            revert PurchaseTooManyForAddress();
        }

        _mintNFTs(toAddress, quantity);

        totalMintsByAddress[toAddress] += quantity;
    }

    function _setSaleDetail(bytes memory initPayload) internal {
        if (
            saleConfig.publicSaleStart != 0 &&
            block.timestamp > saleConfig.publicSaleStart
        ) {
            revert SaleCanNotUpdate();
        }

        SaleConfiguration memory config = abi.decode(
            initPayload,
            (SaleConfiguration)
        );

        if (
            config.publicSaleStart <= block.timestamp ||
            config.publicSaleEnd <= config.publicSaleStart ||
            config.profitSharing > 50 ||
            config.fundsRecipient == address(0)
        ) {
            revert InvalidSaleDetail();
        }

        saleConfig = SaleConfiguration({
            editionSize: config.editionSize,
            profitSharing: config.profitSharing,
            fundsRecipient: config.fundsRecipient,
            publicSalePrice: config.publicSalePrice,
            maxSalePurchasePerAddress: config.maxSalePurchasePerAddress,
            publicSaleStart: config.publicSaleStart,
            publicSaleEnd: config.publicSaleEnd,
            presaleMerkleRoot: config.presaleMerkleRoot,
            cancelable: false
        });

        emit PublicSaleCollection(_msgSender(), block.timestamp);
    }

    function _setBaseURI(string memory _newURI) internal {
        _baseURL = _newURI;
    }

    function _setOwner(address newOwner) internal {
        owner = newOwner;
    }

    function _setManager(address _manager) internal {
        microManager = IMicroManager(_manager);
    }
}
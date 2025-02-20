// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;
import "./openzeppelin_contracts_token_ERC721_extensions_ERC721URIStorage.sol";
import "./openzeppelin_contracts_security_Pausable.sol";
import "./openzeppelin_contracts_token_ERC721_IERC721Receiver.sol";
import "./openzeppelin_contracts_token_ERC20_IERC20.sol";
import "./openzeppelin_contracts_access_Ownable.sol";
import "./openzeppelin_contracts_utils_Counters.sol";
contract HutfinREADOTNFT is ERC721URIStorage, Pausable, Ownable {
    using Counters for Counters.Counter;
    Counters.Counter public currentTokenId;
    IERC20 public usdtToken;
    enum TradeAggrement {
        onAccept,
        OnReject
    }
    TradeAggrement tradeAggrement;
    struct NFTDetails {
        bool sendRequestStatus;
        bool receiveRequestStatus;
        uint256 price;
        bool usdtPayment;
        uint256 tokenId;
        uint256 buyerTokenId;
        uint256 tradeNftTokenId;
        address seller;
        address buyer;
    }
    struct RentableItem {
        bool rentable;
        uint256 rentAmount;
        bool usdtPayment;
        uint256 timeDuration;
    }
    struct RenterInfo {
        bool onRent;
        uint256 rentAmount;
        bool usdtPayment;
        uint256 rentDuration;
        uint256 expireTime;
    }
    mapping(uint256 => RentableItem) public rentables;
    mapping(uint256 => NFTDetails) public nftIdDetail;
    mapping(uint256 => RenterInfo) public renterInfo;
    mapping(address => uint256[]) public tokenIdsCreatorAddress;
    event NftCreated(uint256 tokenId, address to, string uri);
    event NftOnRent(
        uint256 tokenId,
        uint256 price,
        bool usdtPayment,
        uint256 timeDuration,
        address owner
    );
    event SwapNft(
        uint256 tokenId,
        address owner,
        string oldTokenUri,
        string newTokenUri
    );
    event BreedNft(
        uint256 oldtokenId,
        uint256 newtokenId,
        address owner,
        string oldTokenUri,
        string newTokenUri
    );
    event NftOnBarterTrade(
        uint256 tokenId,
        uint256 Price,
        bool usdtPayment,
        address owner
    );
    event TradeNftForNft(
        uint256 sourceTokenId,
        uint256 targetTokenId,
        address tradeFrom,
        address tradeTo
    );
    event TradeDecision(
        uint256 sourceToken,
        uint256 targetToken,
        address tradefrom,
        address tradeTo,
        TradeAggrement tradeAggrement
    );
    event NftRemovedFromRentList(uint256 tokenId, address owner);
    event UsdtTokenChange(address _token);
    event NftUnlisted(uint256 _tokenId, address owner);
    event NftRented(
        uint256 tokenId,
        address renter,
        uint256 expires,
        uint256 rentAmount,
        bool usdtPayment
    );
    event CanceledBarterRequest(uint256 tokenId, address owner);
    constructor() ERC721("READOT-HUTFIN", "READOT-HTF") {
        usdtToken = IERC20(address(0));
        currentTokenId._value = 8030000000 - 1;
    }
    function pause() public onlyOwner {
        _pause();
    }
    function unpause() public onlyOwner {
        _unpause();
    }
    function createNFT(address _to, uint256 _tokenId, string memory _tokenURI) external whenNotPaused {
        safeMint(_to, _tokenId, _tokenURI);
        emit NftCreated(_tokenId, _to, _tokenURI);
    }
    function safeMint(address to, uint256 _tokenId, string memory uri) internal whenNotPaused {
        require(!_exists(_tokenId), "Token ID already exists");
        
        // Mint with the specified token ID
        _safeMint(to, _tokenId);
        _setTokenURI(_tokenId, uri);
        tokenIdsCreatorAddress[to].push(_tokenId);
    }
    function swapOldNFTURIWithNewURI(
        uint256 _tokenId,
        string memory _oldTokenURI,
        string memory _newTokenURI
    ) external whenNotPaused {
        require(_exists(_tokenId), "ERC721Metadata: URI set of nonexistent token");
        require(ownerOf(_tokenId) == _msgSender(), "CRE-NFT: Caller is not owner of the nft");
        require(keccak256(bytes(tokenURI(_tokenId))) == keccak256(bytes(_oldTokenURI)), "CRE-NFT: URIs are not consistent");
        _setTokenURI(_tokenId, _newTokenURI);
        emit SwapNft(_tokenId, _msgSender(), _oldTokenURI, _newTokenURI);
    }
    function breedOldNFTWithNew(
        uint256 _tokenId,
        string memory _oldTokenURI,
        string memory _newTokenURI
    ) external whenNotPaused {
        require(ownerOf(_tokenId) == _msgSender(), "CRE-NFT: Caller is not owner of the nft");
        require(keccak256(bytes(tokenURI(_tokenId))) == keccak256(bytes(_oldTokenURI)), "CRE-NFT: URIs are not consistent");
        require(_exists(_tokenId), "ERC721Metadata: URI set of nonexistent token");
        _burn(_tokenId);
        safeMint(_msgSender(), currentTokenId.current(), _newTokenURI);
        emit BreedNft(_tokenId, currentTokenId.current(), _msgSender(), _oldTokenURI, _newTokenURI);
    }
    function listNftforBarterTrade(
        uint256 _tokenId,
        uint256 _price,
        bool _usdtPayment
    ) external {
        require(ownerOf(_tokenId) == _msgSender(), "You are not Owner of this NFT");
        nftIdDetail[_tokenId] = NFTDetails({
            tokenId: _tokenId,
            price: _price,
            usdtPayment: _usdtPayment,
            seller: _msgSender(),
            buyer: address(0),
            buyerTokenId: 0,
            tradeNftTokenId: 0,
            sendRequestStatus: false,
            receiveRequestStatus: false
        });
        safeTransferFrom(ownerOf(_tokenId), address(this), _tokenId);
        approve(_msgSender(), _tokenId);
        emit NftOnBarterTrade(_tokenId, _price, _usdtPayment, _msgSender());
    }
    function tradeNftForNft(uint256 sourceToken, uint256 targetToken) external {
        require(sourceToken != targetToken, "Trade with the same token id not allowed");
        require(nftIdDetail[sourceToken].seller == _msgSender(), "Caller is not owner of the NFT");
        require(!nftIdDetail[sourceToken].sendRequestStatus, "Source token already placed barter request");
        NFTDetails storage targetNft = nftIdDetail[targetToken];
        require(!targetNft.receiveRequestStatus, "Target Token already received barter request");
        targetNft.buyerTokenId = sourceToken;
        targetNft.buyer = _msgSender();
        targetNft.receiveRequestStatus = true;
        nftIdDetail[sourceToken].sendRequestStatus = true;
        nftIdDetail[sourceToken].tradeNftTokenId = targetToken;
        emit TradeNftForNft(sourceToken, targetToken, _msgSender(), targetNft.seller);
    }
    function acceptTradeRequest(TradeAggrement _tradeAggrementStatus, uint256 _tokenId) external {
        require(nftIdDetail[_tokenId].seller == _msgSender(), "Caller is not owner of the NFT");
        require(nftIdDetail[_tokenId].receiveRequestStatus, "No barter request received");
        if (_tradeAggrementStatus == TradeAggrement.OnReject) {
            _cancelTradeRequest(_tokenId);
        } else {
            _completeTradeRequest(_tokenId);
        }
    }
    function _cancelTradeRequest(uint256 _tokenId) internal {
        nftIdDetail[_tokenId].receiveRequestStatus = false;
        nftIdDetail[_tokenId].buyer = address(0);
        uint256 buyerId = nftIdDetail[_tokenId].buyerTokenId;
        nftIdDetail[buyerId].tradeNftTokenId = 0;
        nftIdDetail[buyerId].sendRequestStatus = false;
        nftIdDetail[_tokenId].buyerTokenId = 0;
    }
    function _completeTradeRequest(uint256 _tokenId) internal {
        uint256 buyerTokenId = nftIdDetail[_tokenId].buyerTokenId;
        safeTransferFrom(address(this), nftIdDetail[_tokenId].buyer, _tokenId);
        safeTransferFrom(address(this), nftIdDetail[_tokenId].seller, buyerTokenId);
        emit TradeDecision(buyerTokenId, _tokenId, nftIdDetail[_tokenId].buyer, nftIdDetail[_tokenId].seller, TradeAggrement.onAccept);
        delete nftIdDetail[buyerTokenId];
        delete nftIdDetail[_tokenId];
    }
    function unlistNft(uint256 _tokenId) external {
        require(nftIdDetail[_tokenId].seller == _msgSender(), "Caller is not owner of the NFT");
        safeTransferFrom(address(this), _msgSender(), _tokenId);
        delete nftIdDetail[_tokenId];
        emit NftUnlisted(_tokenId, _msgSender());
    }
    function setUsdtToken(address _token) external onlyOwner {
        usdtToken = IERC20(_token);
        emit UsdtTokenChange(_token);
    }
}
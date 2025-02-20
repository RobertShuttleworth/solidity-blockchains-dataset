// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.9; // solhint-disable-line

import {IERC721} from "./openzeppelin_contracts_token_ERC721_IERC721.sol";
import {IERC20} from "./openzeppelin_contracts_token_ERC20_IERC20.sol";
import {Ownable2StepUpgradeable} from "./openzeppelin_contracts-upgradeable_access_Ownable2StepUpgradeable.sol";
import {ReentrancyGuardUpgradeable} from "./openzeppelin_contracts-upgradeable_security_ReentrancyGuardUpgradeable.sol";
import {SafeERC20} from "./openzeppelin_contracts_token_ERC20_utils_SafeERC20.sol";
import {IEarthmetaMarketplace, Errors} from "./contracts_interfaces_IEarthmetaMarketplace.sol";
import {IEarthmeta} from "./contracts_interfaces_IEarthmeta.sol";
import {TransferErrors} from "./contracts_interfaces_IErrors.sol";

/// @title EarthmetaMarketplace contract.
/// @author EarthmetaMarketplace 2024.
contract EarthmetaMarketplace is IEarthmetaMarketplace, ReentrancyGuardUpgradeable, Ownable2StepUpgradeable {
    using SafeERC20 for IERC20;

    string public constant VERSION = "1.0.0";

    address public constant NATIVE_ADDRESS = 0x0000000000000000000000000000000000000000;

    mapping(address => bool) public tokens;
    mapping(address => bool) public nftAddresses;
    mapping(address => mapping(uint256 => uint256)) public listings;

    struct RequestBuy {
        address receiver;
        address nftAddress;
        uint256 nftId;
        address tokenAddress;
        uint256 price;
    }

    struct Request {
        uint256 nftId;
        address nftAddress;
        uint256 priceUSD;
    }

    address public signer;

    IEarthmeta public earthmeta;

    modifier isSigner() {
        if (msg.sender != signer) {
            revert Errors.NotNftOwner();
        }
        _;
    }

    function isNFTOwnerOrSignerOrSigner(address _owner, address _sender) internal view {
        if (_sender != _owner && _sender != signer) {
            revert Errors.NotNftOwner();
        }
    }

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    /// @notice initialize TokenGateway
    /// @param _owner the contract owner.
    /// @param _earthmeta earthmetaDAO address.
    function initialize(address _owner, address _signer, IEarthmeta _earthmeta) external initializer {
        __ReentrancyGuard_init();
        __Ownable2Step_init();
        signer = _signer;
        earthmeta = _earthmeta;
        transferOwnership(_owner);
    }

    /// @notice list items.
    /// @param requests list request list items.
    function listItemMany(Request[] memory requests) external {
        for (uint256 i = 0; i < requests.length; i++) {
            listItem(requests[i]);
        }
    }

    function listItem(Request memory request) internal {
        IERC721 nft = IERC721(request.nftAddress);
        address owner = nft.ownerOf(request.nftId);
        isNFTOwnerOrSignerOrSigner(owner, msg.sender);

        if (!nftAddresses[request.nftAddress]) {
            revert Errors.NftAddressNotAllowed(request.nftAddress);
        }

        if (listings[request.nftAddress][request.nftId] > 0) {
            revert Errors.AlreadyListed(request.nftAddress, request.nftId);
        }

        if (request.priceUSD == 0) {
            revert Errors.PriceMustBeAboveZero();
        }

        if (!IERC721(request.nftAddress).isApprovedForAll(owner, address(this))) {
            revert Errors.NotApprovedForMarketplace();
        }

        listings[request.nftAddress][request.nftId] = request.priceUSD;
        emit ItemListed(owner, request.nftAddress, request.nftId, request.priceUSD);
    }

    /// @notice cancel a listing.
    /// @param requests list of request cancle listing.
    function cancelListingMany(Request[] memory requests) external {
        for (uint256 i = 0; i < requests.length; i++) {
            cancelListing(requests[i]);
        }
    }

    function cancelListing(Request memory request) internal {
        uint256 price = listings[request.nftAddress][request.nftId];
        if (price == 0) {
            revert Errors.NotListed(request.nftAddress, request.nftId);
        }

        IERC721 nft = IERC721(request.nftAddress);
        address owner = nft.ownerOf(request.nftId);
        isNFTOwnerOrSignerOrSigner(owner, msg.sender);

        delete (listings[request.nftAddress][request.nftId]);
        emit ItemCanceled(owner, request.nftAddress, request.nftId, request.priceUSD);
    }

    /// @notice cancel a listing.
    /// @param requests list of request update listing.
    function updateListingMany(Request[] memory requests) external {
        for (uint256 i = 0; i < requests.length; i++) {
            updateListing(requests[i]);
        }
    }

    function updateListing(Request memory request) internal {
        uint256 price = listings[request.nftAddress][request.nftId];
        if (price == 0) {
            revert Errors.NotListed(request.nftAddress, request.nftId);
        }

        IERC721 nft = IERC721(request.nftAddress);
        address owner = nft.ownerOf(request.nftId);
        isNFTOwnerOrSignerOrSigner(owner, msg.sender);
        listings[request.nftAddress][request.nftId] = request.priceUSD;
        emit ItemUpdated(owner, request.nftAddress, request.nftId, request.priceUSD);
    }

    /// @notice buy an item.
    /// @param requests a list of request buy.
    function buyMany(RequestBuy[] memory requests) external payable isSigner nonReentrant {
        for (uint256 i = 0; i < requests.length; i++) {
            RequestBuy memory req = requests[i];
            _buyItem(req.receiver, req.nftAddress, req.tokenAddress, req.nftId, req.price);
        }
    }

    function _buyItem(
        address _receiver,
        address _nftAddress,
        address _tokenAddress,
        uint256 _nftId,
        uint256 _price
    ) internal {
        IERC721 nft = IERC721(_nftAddress);

        address owner = nft.ownerOf(_nftId);

        (address[] memory receivers, uint256[] memory fees, uint256 totalFees) = earthmeta.getRoyaltyMetadata(
            _nftAddress,
            _nftId,
            _price
        );

        if (_tokenAddress == NATIVE_ADDRESS) {
            if (msg.value != _price) {
                revert Errors.PriceNotMet(_nftAddress, _nftId, _price);
            }

            for (uint256 i = 0; i < receivers.length; i++) {
                (bool sent, ) = receivers[i].call{value: fees[i]}("");
                if (!sent) {
                    revert TransferErrors.ErrorToSendFees(receivers[i]);
                }
                emit ItemFee(i, receivers[i], _nftAddress, _nftId, _tokenAddress, fees[i]);
            }

            payable(owner).transfer(_price - totalFees);
        } else {
            IERC20(_tokenAddress).safeTransferFrom(signer, address(this), _price);

            for (uint256 i = 0; i < receivers.length; i++) {
                IERC20(_tokenAddress).safeTransfer(receivers[i], fees[i]);
                emit ItemFee(i, receivers[i], _nftAddress, _nftId, _tokenAddress, fees[i]);
            }
            IERC20(_tokenAddress).safeTransfer(owner, _price - totalFees);
            emit ItemBought(_receiver, _nftAddress, _nftId, _tokenAddress, _price, _price - totalFees);
        }
        delete (listings[_nftAddress][_nftId]);
        IERC721(_nftAddress).safeTransferFrom(owner, _receiver, _nftId);
    }

    /// @notice set token. only admin can call this function.
    /// @param _tokenAddress the token required to buy the token.
    /// @param _status token status.
    function setToken(address _tokenAddress, bool _status) external onlyOwner {
        if (_status) {
            tokens[_tokenAddress] = _status;
        } else {
            delete tokens[_tokenAddress];
        }

        emit SetToken(_tokenAddress, _status);
    }

    /// @notice set nft address. only admin can call this function.
    /// @param _nftAddress the nft address.
    /// @param _status token status.
    function setNftAddress(address _nftAddress, bool _status) external onlyOwner {
        if (_status) {
            nftAddresses[_nftAddress] = _status;
        } else {
            delete nftAddresses[_nftAddress];
        }
        emit SetNftAddress(_nftAddress, _status);
    }

    /// @notice set the signer address.
    /// @param _signer the new signer address.
    function setSigner(address _signer) external onlyOwner {
        signer = _signer;
    }

    /// @notice clean the listing when the token is transfered.
    /// @param _nftId the token id.
    function cleanListing(uint256 _nftId) external {
        if (listings[msg.sender][_nftId] > 0) return;
        delete listings[msg.sender][_nftId];
    }
}
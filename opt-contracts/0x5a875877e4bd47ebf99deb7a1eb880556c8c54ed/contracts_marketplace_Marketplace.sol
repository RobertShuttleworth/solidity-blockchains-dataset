// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import "./openzeppelin_contracts-upgradeable_access_AccessControlEnumerableUpgradeable.sol";
import "./openzeppelin_contracts_token_ERC20_utils_SafeERC20.sol";
import "./openzeppelin_contracts-upgradeable_utils_structs_EnumerableSetUpgradeable.sol";
import "./openzeppelin_contracts-upgradeable_utils_StringsUpgradeable.sol";
import "./openzeppelin_contracts-upgradeable_utils_CountersUpgradeable.sol";
import "./openzeppelin_contracts-upgradeable_security_PausableUpgradeable.sol";
import "./openzeppelin_contracts-upgradeable_token_ERC1155_utils_ERC1155HolderUpgradeable.sol";
import "./openzeppelin_contracts-upgradeable_security_ReentrancyGuardUpgradeable.sol";
import "./openzeppelin_contracts_interfaces_IERC721.sol";
import "./openzeppelin_contracts_interfaces_IERC1155.sol";
import "./openzeppelin_contracts_token_ERC20_IERC20.sol";
import "./openzeppelin_contracts-upgradeable_proxy_utils_UUPSUpgradeable.sol";

/// @title Marketplace Contract
/// @notice Contract that implements all the functionality of the marketplace

contract Marketplace is
    AccessControlEnumerableUpgradeable,
    PausableUpgradeable,
    ERC1155HolderUpgradeable,
    ReentrancyGuardUpgradeable,
    UUPSUpgradeable
{
    using SafeERC20 for IERC20;
    using CountersUpgradeable for CountersUpgradeable.Counter;
    using EnumerableSetUpgradeable for EnumerableSetUpgradeable.AddressSet;

    EnumerableSetUpgradeable.AddressSet private whitelistedTokens20; // whitelist token
    EnumerableSetUpgradeable.AddressSet private whitelistedTokens_721; // whitelist 721

    struct OfferData {
        address creator;
        address buyer;
        uint256 price;
        address token;
        uint256 tokenId;
        address saleToken;
        bool active;
        uint32 creatingTime;
    }

    mapping(uint256 => OfferData) public offers; // offers structure info

    CountersUpgradeable.Counter internal _offersCounter; // offers counter

    uint256 public ethBalance; // eth balance on contract (like fee)
    mapping(address => uint256) public tokenBalances; // token balance on contract (like fee)

    bytes32 public constant OWNER_MARKETPLACE_ROLE =
        keccak256("OWNER_MARKETPLACE_ROLE");

    uint32 public constant TEN_PERCENTS = 1000; // 10%
    address public feeToken; // fee token address
    mapping(address => uint256[]) public userOffers; // user offers

    event CreatedOffer(
        uint256 offerId,
        address user,
        address token,
        uint256 tokenId,
        address saleToken,
        uint256 price,
        uint32 creatingTime
    );
    event OfferCanceled(address user, uint256 offerId);
    event SetFeeToken(address feeToken);
    event EditOffer(
        address user,
        uint256 offerId,
        uint256 price,
        address saleToken
    );
    event AcceptOffer(address user, uint256 offerId);

    /// @dev Check if caller is contract owner

    modifier onlyOwner() {
        require(
            hasRole(OWNER_MARKETPLACE_ROLE, msg.sender),
            "Caller is not an owner."
        );
        _;
    }

    receive() external payable {}

    fallback() external payable {}

    function _authorizeUpgrade(
        address newImplementation
    ) internal override onlyRole(OWNER_MARKETPLACE_ROLE) {}

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    /// @dev Sets main dependencies and constants
    /// @param _feeToken set fee token address

    function initialize(address _feeToken) public initializer {
        __AccessControlEnumerable_init();
        __Pausable_init();
        __ERC1155Holder_init();
        __ReentrancyGuard_init();
        __UUPSUpgradeable_init();

        _setupRole(DEFAULT_ADMIN_ROLE, _msgSender());
        _setupRole(OWNER_MARKETPLACE_ROLE, msg.sender);
        _setRoleAdmin(OWNER_MARKETPLACE_ROLE, OWNER_MARKETPLACE_ROLE);
        _setRoleAdmin(DEFAULT_ADMIN_ROLE, OWNER_MARKETPLACE_ROLE);
        setFeeToken(_feeToken);
        whitelistedTokens20.add(_feeToken);
    }

    /// @dev add token to whitelist
    /// @param tokens - array of tokens addresses
    /// @param tokensType - erc 20 or erc721 type

    function addTokensToWhitelist(
        address[] calldata tokens,
        bool[] calldata tokensType
    ) external onlyOwner {
        require(tokens.length == tokensType.length, "Unequal length.");
        for (uint256 i; i < tokens.length; ++i) {
            if (!tokensType[i]) {
                whitelistedTokens20.add(tokens[i]);
            } else {
                whitelistedTokens_721.add(tokens[i]);
            }
        }
    }

    /// @dev remove token from whitelist
    /// @param tokens - array of tokens addresses
    /// @param tokensType - erc 20 or erc721 type

    function removeTokensFromWhitelist(
        address[] calldata tokens,
        bool[] calldata tokensType
    ) external onlyOwner {
        require(tokens.length == tokensType.length, "Unequal length.");
        for (uint256 i; i < tokens.length; ++i) {
            if (!tokensType[i]) {
                whitelistedTokens20.remove(tokens[i]);
            } else {
                whitelistedTokens_721.remove(tokens[i]);
            }
        }
    }

    /// @dev get list of whitelisted tokens

    function getWhitelistedTokens(
        bool tokenType
    ) external view returns (address[] memory) {
        if (tokenType) {
            return whitelistedTokens_721.values();
        } else {
            return whitelistedTokens20.values();
        }
    }

    /// @dev set contract pause

    function setPause(bool pause) external onlyOwner {
        if (pause) {
            _pause();
        } else {
            _unpause();
        }
    }

    /// @dev set fee token address

    function setFeeToken(address _feeToken) public onlyOwner {
        feeToken = _feeToken;
        emit SetFeeToken(_feeToken);
    }

    /// @dev Create offer by user
    /// @notice Function for creating new offer on Marketplace
    /// @param token - NFT token addresses which will be exhibited
    /// @param tokenId - NFT token id
    /// @param saleToken - token address for which will be sold
    /// @param price - sale price in token decimals.

    function createOffer(
        address token,
        uint256 tokenId,
        address saleToken,
        uint256 price
    ) external whenNotPaused nonReentrant {
        require(
            whitelistedTokens_721.contains(token),
            "Token not in whitelist."
        );
        if (saleToken != address(0)) {
            require(
                whitelistedTokens20.contains(saleToken),
                "Cannot be sold for this token."
            );
        }
        require(
            address(this) == IERC721(token).getApproved(tokenId),
            "Not approved token"
        );

        uint256 offerId = uint256(_offersCounter.current());

        offers[offerId] = OfferData(
            msg.sender,
            address(0),
            price,
            token,
            tokenId,
            saleToken,
            true,
            uint32(block.timestamp)
        );
        userOffers[msg.sender].push(offerId);

        _offersCounter.increment();

        emit CreatedOffer(
            offerId,
            msg.sender,
            token,
            tokenId,
            saleToken,
            price,
            uint32(block.timestamp)
        );
    }

    /// @dev purchase created offer
    /// @notice Function for buying a certain offer
    /// @param offerId - id of the offer

    function acceptOffer(
        uint256 offerId
    ) external payable whenNotPaused nonReentrant {
        require(isOfferActive(offerId), "Offer does not active.");
        OfferData memory offer = getOfferInfo(offerId);
        require(offer.creator != msg.sender, "You are owner of the offer.");
        offer.buyer = msg.sender;
        offer.active = false;
        offers[offerId] = offer;

        if (offer.saleToken != address(0)) {
            require(msg.value == 0, "Unnecessary transfer of Ether.");
            uint16 percent;

            offer.saleToken == feeToken ? percent = 200 : percent = 250;

            uint256 platformFee = (offer.price * percent) / 10000; // fee 2.5% or 2.0%
            tokenBalances[offer.saleToken] += platformFee;

            IERC20(offer.saleToken).safeTransferFrom(
                msg.sender,
                address(this),
                platformFee
            );
            IERC20(offer.saleToken).safeTransferFrom(
                msg.sender,
                offer.creator,
                offer.price - platformFee
            );
        } else {
            require(offer.price == msg.value, "Value is not equal.");
            uint256 expectedValue = (offer.price * 250) / 10000; // fee 2.5%
            ethBalance += expectedValue;
            (bool sent, ) = payable(offer.creator).call{
                value: msg.value - expectedValue
            }("");
            require(sent, "Failed to send Ether");
        }

        IERC721(offer.token).safeTransferFrom(
            offer.creator,
            msg.sender,
            offer.tokenId,
            bytes("")
        );
        emit AcceptOffer(msg.sender, offerId);
    }

    /// @dev cancel created offer
    // @param id - offer id

    function cancelOffer(uint256 id) external whenNotPaused nonReentrant {
        require(isOfferActive(id), "Offer does not active.");
        require(
            offers[id].creator == msg.sender,
            "You are not owner of the offer."
        );
        offers[id].active = false;
        emit OfferCanceled(msg.sender, id);
    }

    /// @dev edit offer function to edit the specified offer
    /// @param offerId - id of the created offer
    /// @param price - new price for offer
    /// @param saleToken - new token address for which will be sold

    function editOffer(
        uint256 offerId,
        uint256 price,
        address saleToken
    ) external whenNotPaused nonReentrant {
        require(isOfferActive(offerId), "Offer does not active.");
        OfferData memory offer = getOfferInfo(offerId);

        require(
            offers[offerId].creator == msg.sender,
            "You are not owner of the offer."
        );

        if (offer.price != price) {
            require(price > 0, "Price should be positive");
            offers[offerId].price = price;
        }
        if (offer.saleToken != saleToken) {
            if (saleToken != address(0)) {
                require(
                    whitelistedTokens20.contains(saleToken),
                    "Cannot be sold for this token."
                );
            }
            offers[offerId].saleToken = saleToken;
        }

        emit EditOffer(msg.sender, offerId, price, saleToken);
    }

    /// @dev Withdraw all ETH from contract to the owner

    function unlockETH() external onlyOwner {
        uint256 amount = ethBalance;
        require(amount > 0, "Balance is zero.");
        ethBalance = 0;
        (bool sent, ) = msg.sender.call{value: amount}("");
        require(sent, "Failed to send Ether");
    }

    /// @dev Withdraw ERC20 token balance from contract address
    /// @param tokenAddress address of the ERC20 token contract whose tokens will be withdrawn to the recipient

    function unlockTokens(IERC20 tokenAddress) external onlyOwner {
        uint256 amount = tokenBalances[address(tokenAddress)];
        require(amount > 0, "Balance is zero.");
        tokenBalances[address(tokenAddress)] = 0;
        tokenAddress.safeTransfer(msg.sender, amount);
    }

    function isOfferActive(uint256 offerId) public view returns (bool) {
        return offers[offerId].active;
    }

    /// @notice Returns full information about offer
    /// @dev Returns offer object by id with all params
    /// @param offerId id of offer
    /// @return offer object with all contains params
    function getOfferInfo(
        uint256 offerId
    ) public view returns (OfferData memory) {
        return offers[offerId];
    }

    /// @dev Check if this contract support interface
    /// @dev Need for checking by other contract if this contract support standard
    /// @param interfaceId interface identifier

    function supportsInterface(
        bytes4 interfaceId
    )
        public
        view
        virtual
        override(AccessControlEnumerableUpgradeable, ERC1155ReceiverUpgradeable)
        returns (bool)
    {
        return super.supportsInterface(interfaceId);
    }

    function getUserOffers(
        address user
    ) external view returns (uint256[] memory) {
        return userOffers[user];
    }

    uint256[100] __gap;
}
// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.20;

import "./openzeppelin_contracts-upgradeable_proxy_utils_Initializable.sol";
import "./openzeppelin_contracts-upgradeable_proxy_utils_UUPSUpgradeable.sol";
import "./openzeppelin_contracts-upgradeable_security_PausableUpgradeable.sol";
import "./openzeppelin_contracts-upgradeable_security_ReentrancyGuardUpgradeable.sol";
import "./openzeppelin_contracts-upgradeable_access_OwnableUpgradeable.sol";
import "./openzeppelin_contracts-upgradeable_token_ERC20_utils_SafeERC20Upgradeable.sol";
import "./openzeppelin_contracts-upgradeable_token_ERC20_IERC20Upgradeable.sol";
import "./openzeppelin_contracts-upgradeable_token_ERC721_IERC721Upgradeable.sol";
import "./openzeppelin_contracts-upgradeable_interfaces_IERC2981Upgradeable.sol";
import "./contracts_library_LibOrder.sol";
import "./contracts_interface_IBlockUnblockAccess.sol";
import "./openzeppelin_contracts-upgradeable_utils_cryptography_EIP712Upgradeable.sol";
import "./openzeppelin_contracts-upgradeable_utils_cryptography_ECDSAUpgradeable.sol";
import "./openzeppelin_contracts-upgradeable_token_ERC20_extensions_IERC20MetadataUpgradeable.sol";

contract ExchangeV3 is
    Initializable,
    UUPSUpgradeable,
    OwnableUpgradeable,
    PausableUpgradeable,
    ReentrancyGuardUpgradeable,
    EIP712Upgradeable
{
    uint256[48] private __gap;
    using SafeERC20Upgradeable for IERC20Upgradeable;

    string public constant name = "Exchange";
    IBlockUnblockAccess public blockAccessContract;

    mapping(address => mapping(uint256 => LibOrder.Order)) public SaleStatus;
    mapping(bytes32 => bytes4) public OrderStatus;

    bytes4 public constant NEW_ORDER_CLASS = bytes4(keccak256("NEW"));
    bytes4 public constant COMPLETED_ORDER_CLASS =
        bytes4(keccak256("COMPLETED"));
    bytes4 public constant CANCELLED_ORDER_CLASS =
        bytes4(keccak256("CANCELLED"));

    address public platformFeeAddress;
    uint256 public sellerPlatformFeePercentage;
    uint256 public buyerPlatformFeePercentage;
    uint256 public sellerPlatformFeeFixedAmount;
    uint256 public buyerPlatformFeeFixedAmount;

    event OrderCreated(LibOrder.Order order);
    event OrderCancelled(LibOrder.Order order);
    event OrderPurchased(LibOrder.Order order);
    event BidAccepted(LibOrder.Bid bid);
    event FeeSettingUpdated(
        address indexed platformFeeAddress,
        uint256 sellerPlatformFeePercentage,
        uint256 buyerPlatformFeePercentage,
        uint256 sellerPlatformFeeFixedAmount,
        uint256 buyerPlatformFeeFixedAmount
    );

    /**
     * @dev Initializes the contract and sets the initial values.
     */
    function initialize(address _blockAccessContract) external initializer {
        __Pausable_init_unchained();
        __Ownable_init_unchained();
        __ReentrancyGuard_init_unchained();
        __EIP712_init_unchained("Bid", "1");
        blockAccessContract = IBlockUnblockAccess(_blockAccessContract);
    }

    /**
     * @dev Creates a sell order
     *
     * Requirements:
     * @param order - Object of sell order.
     *
     * Emits a {OrderCreated} event, indicating the order.
     */
    function createOrder(
        LibOrder.Order memory order
    ) external whenNotPaused nonReentrant {
        require(
            blockAccessContract.blockedUsers(msg.sender) == false,
            "Exchange: User blocked"
        );
        // Seller validation
        require(
            order.seller == msg.sender,
            "Exchange: Only seller can create order"
        );
        // Nft owner validation
        IERC721Upgradeable token = IERC721Upgradeable(order.tokenAddress);
        require(
            token.ownerOf(order.tokenId) == msg.sender,
            "Exchange: Not the owner of the token"
        );
        // Nft approval validation
        require(
            token.getApproved(order.tokenId) == address(this),
            "Exchange: Token not approved"
        );

        uint256 totalSellerFee = calculateSellerPlatformFee(
            order.price,
            IERC20MetadataUpgradeable(order.currencyAddress)
        );
        if (totalSellerFee > 0) {
            IERC20Upgradeable(order.currencyAddress).safeTransferFrom(
                msg.sender,
                platformFeeAddress,
                totalSellerFee
            );
        }

        // get unique key
        bytes32 hashKey = LibOrder._genHashKey(order);
        // existing order validation
        require(
            OrderStatus[hashKey] == 0x00000000,
            "Exchange: Order already exists"
        );

        // validate existing order and update status
        LibOrder.Order memory existingOrder = SaleStatus[order.tokenAddress][
            order.tokenId
        ];
        bytes32 orderHashKey = LibOrder._genHashKey(existingOrder);
        if (OrderStatus[orderHashKey] == NEW_ORDER_CLASS)
            OrderStatus[orderHashKey] = 0x00000000;

        // update status
        SaleStatus[order.tokenAddress][order.tokenId] = order;
        OrderStatus[hashKey] = NEW_ORDER_CLASS;

        emit OrderCreated(order);
    }

    /**
     * @dev Cancel sell order
     *
     * Requirements:
     * @param order - Object of sell order.
     *
     * Emits a {OrderCancelled} event, indicating the order.
     */
    function cancelOrder(LibOrder.Order memory order) public whenNotPaused {
        require(
            blockAccessContract.blockedUsers(msg.sender) == false,
            "Exchange: User blocked"
        );
        // Seller validation
        require(
            order.seller == msg.sender,
            "Exchange: Only seller can cancel order"
        );

        // get unique key
        bytes32 hashKey = LibOrder._genHashKey(order);
        // check for order status
        _validateOrderStatus(hashKey);

        // update order status
        OrderStatus[hashKey] = CANCELLED_ORDER_CLASS;

        emit OrderCancelled(order);
    }

    /**
     * @dev Complete sell order
     *
     * Requirements:
     * @param order - Object of sell order.
     *
     * Emits a {OrderPurchased} event, indicating the order.
     */
    function completeOrder(
        LibOrder.Order memory order
    ) external whenNotPaused nonReentrant {
        require(
            blockAccessContract.blockedUsers(msg.sender) == false,
            "Exchange: User blocked"
        );
        // get unique key
        bytes32 hashKey = LibOrder._genHashKey(order);
        // check for order status
        _validateOrderStatus(hashKey);

        // update order status
        OrderStatus[hashKey] = COMPLETED_ORDER_CLASS;

        // Transfer royalty
        (address receiver, uint256 royaltyAmount) = IERC2981Upgradeable(
            order.tokenAddress
        ).royaltyInfo(order.tokenId, order.price);
        IERC20Upgradeable(order.currencyAddress).safeTransferFrom(
            msg.sender,
            receiver,
            royaltyAmount
        );

        // Transfer buyer platform fee
        uint256 totalBuyerFee = calculateBuyerPlatformFee(
            order.price,
            IERC20MetadataUpgradeable(order.currencyAddress)
        );
        if (totalBuyerFee > 0) {
            IERC20Upgradeable(order.currencyAddress).safeTransferFrom(
                msg.sender,
                platformFeeAddress,
                totalBuyerFee
            );
        }

        // Transfer amount
        IERC20Upgradeable(order.currencyAddress).safeTransferFrom(
            msg.sender,
            order.seller,
            order.price - royaltyAmount
        );

        // Transfer NFT
        IERC721Upgradeable(order.tokenAddress).safeTransferFrom(
            order.seller,
            msg.sender,
            order.tokenId
        );

        emit OrderPurchased(order);
    }

    function acceptBid(
        LibOrder.Bid memory bid,
        bytes calldata signature
    ) external whenNotPaused nonReentrant {
        require(
            blockAccessContract.blockedUsers(msg.sender) == false,
            "Exchange: User blocked"
        );
        require(
            blockAccessContract.blockedUsers(bid.to) == false,
            "Exchange: User blocked"
        );

        // Nft owner validation
        IERC721Upgradeable token = IERC721Upgradeable(bid.tokenAddress);
        require(
            token.ownerOf(bid.tokenId) == msg.sender,
            "Exchange: Not the owner of the token"
        );

        // Nft approval validation
        require(
            token.getApproved(bid.tokenId) == address(this),
            "Exchange: Token not approved"
        );

        // verify signature
        bytes32 structHash = LibOrder._genBidHash(bid);
        bytes32 hashTypedData = _hashTypedDataV4(structHash);
        address signed = verifySignature(hashTypedData, signature);
        require(signed == bid.to, "Exchange: Signature Incorrect");

        // check sale status, if in sale cancel that sale
        (bool inSale, LibOrder.Order memory order) = getSaleStatus(
            bid.tokenAddress,
            bid.tokenId
        );
        if (inSale) cancelOrder(order);

        // transfer amount
        IERC20Upgradeable currencyAddress = IERC20Upgradeable(bid.currency);
        currencyAddress.transferFrom(bid.to, msg.sender, bid.amount);

        // transfer nft
        token.safeTransferFrom(msg.sender, bid.to, bid.tokenId);

        emit BidAccepted(bid);
    }

    /**
     * @dev Pause the contract (stopped state) by owner.
     *
     * Requirements:
     * - The contract must not be paused.
     * 
     * Emits a {Paused} event.
     */
    function pause() external onlyOwner {
        _pause();
    }

    /**
     * @dev Unpause the contract (normal state) by owner.
     *
     * Requirements:
     * - The contract must be paused.
     *
     * Emits a {Unpaused} event.
     */
    function unpause() external onlyOwner whenPaused {
        _unpause();
    }

    /**
     * @dev Get order status.
     * @return inSale - sale status.
     * @return orderData - order object.
     */
    function getSaleStatus(
        address nftAddress,
        uint256 tokenId
    ) public view returns (bool inSale, LibOrder.Order memory orderData) {
        LibOrder.Order memory order = SaleStatus[nftAddress][tokenId];
        bytes32 hashKey = LibOrder._genHashKey(order);
        if (OrderStatus[hashKey] == NEW_ORDER_CLASS) return (true, order);
        else return (false, order);
    }

    /**
     * @dev Internal function to verify the signature.
     * @param hash - bytes of signature params.
     * @param signature.
     * @return address - signer address
     */
    function verifySignature(
        bytes32 hash,
        bytes calldata signature
    ) internal pure returns (address) {
        return ECDSAUpgradeable.recover(hash, signature);
    }

    /**
     * @dev Internal function to validate order status.
     * @param hashKey - order hash.
     */
    function _validateOrderStatus(bytes32 hashKey) internal view {
        require(
            OrderStatus[hashKey] == NEW_ORDER_CLASS,
            "Exchange: Order is not created yet"
        );
        require(
            OrderStatus[hashKey] != COMPLETED_ORDER_CLASS,
            "Exchange: Order is already completed"
        );
        require(
            OrderStatus[hashKey] != CANCELLED_ORDER_CLASS,
            "Exchange: Order is already cancelled"
        );
    }

    function _authorizeUpgrade(
        address newImplementation
    ) internal override onlyOwner {}

    /**
     * @notice Calculates the total platform fee for the seller by combining percentage and fixed fees
     * @param _nftTokenPrice The NFT token price to calculate percentage fee from
     * @param _currencyToken The ERC20 token used for payment
     * @return The total platform fee amount in payment token
     */
    function calculateSellerPlatformFee(
        uint256 _nftTokenPrice,
        IERC20MetadataUpgradeable _currencyToken
    ) public view returns (uint256) {
        uint256 percentageFeeAmount = (_nftTokenPrice *
            sellerPlatformFeePercentage) / 10_000;
        uint256 fixedFeeAmount = calculateEquivalentTokenAmount(
            _currencyToken,
            sellerPlatformFeeFixedAmount
        );
        return percentageFeeAmount + fixedFeeAmount;
    }

    /**
     * @notice Calculates the total platform fee for the buyer, including both percentage and fixed fees.
     * @param _nftTokenPrice The price of the NFT token for which the platform fee is calculated.
     * @param _currencyToken The ERC20 token used as currency for the transaction.
     * @return The total platform fee for the buyer, combining percentage and fixed fees.
     */
    function calculateBuyerPlatformFee(
        uint256 _nftTokenPrice,
        IERC20MetadataUpgradeable _currencyToken
    ) public view returns (uint256) {
        uint256 percentageFeeAmount = (_nftTokenPrice *
            buyerPlatformFeePercentage) / 10_000;
        uint256 fixedFeeAmount = calculateEquivalentTokenAmount(
            _currencyToken,
            buyerPlatformFeeFixedAmount
        );
        return percentageFeeAmount + fixedFeeAmount;
    }

    /**
     * @dev Calculates the equivalent token amount in smallest units based on the token's decimals.
     * @param _token The ERC20 token for which the equivalent amount is calculated.
     * @param _amount The amount of tokens in standard units.
     * @return The equivalent amount in smallest units.
     */
    function calculateEquivalentTokenAmount(
        IERC20MetadataUpgradeable _token,
        uint256 _amount
    ) internal view returns (uint256) {
        uint8 decimals = _token.decimals();
        return _amount * (10 ** decimals);
    }

    /**
     * @notice Updates platform fee settings for buyers and sellers
     * @param _platformFeeAddress Address to receive platform fees
     * @param _buyerPlatformFeePercentage Platform fee percentage charged to buyers (max 100%)
     * @param _sellerPlatformFeePercentage Platform fee percentage charged to sellers (max 100%)
     * @param _sellerPlatformFeeFixedAmount Fixed fee amount charged to sellers
     * @param _buyerPlatformFeeFixedAmount Fixed fee amount charged to buyers
     * @dev Only callable by contract owner
     * @dev Emits FeeSettingUpdated event
     */
    function setFeeSettings(
        address _platformFeeAddress,
        uint256 _sellerPlatformFeePercentage,
        uint256 _buyerPlatformFeePercentage,
        uint256 _sellerPlatformFeeFixedAmount,
        uint256 _buyerPlatformFeeFixedAmount
    ) external onlyOwner {
        require(
            _buyerPlatformFeePercentage <= 10_000,
            "Exchange: Buyer platform fee should be less than or equal to 100%"
        );
        require(
            _sellerPlatformFeePercentage <= 10_000,
            "Exchange: Seller platform fee should be less than or equal to 100%"
        );
        require(
            _platformFeeAddress != address(0),
            "Exchange: Address cannot be zero address"
        );
        platformFeeAddress = _platformFeeAddress;
        sellerPlatformFeePercentage = _sellerPlatformFeePercentage;
        buyerPlatformFeePercentage = _buyerPlatformFeePercentage;
        sellerPlatformFeeFixedAmount = _sellerPlatformFeeFixedAmount;
        buyerPlatformFeeFixedAmount = _buyerPlatformFeeFixedAmount;

        emit FeeSettingUpdated(
            platformFeeAddress,
            sellerPlatformFeePercentage,
            buyerPlatformFeePercentage,
            sellerPlatformFeeFixedAmount,
            buyerPlatformFeeFixedAmount
        );
    }
}
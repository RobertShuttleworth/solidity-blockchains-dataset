// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.20;

library LibOrder {

    struct Order {
        address seller;
        address tokenAddress;
        uint256 tokenId;
        address currencyAddress;
        uint256 price;
        uint256 nonce;
    }

    struct Bid {
        address to;
        uint256 amount;
        address currency;
        uint256 quantity;
        address tokenAddress;
        uint256 tokenId; 
    }

    bytes32 private constant BID_TYPEHASH = keccak256("Bid(address to,uint256 amount,address currency,uint256 quantity,address tokenAddress,uint256 tokenId)");

    /**
     * @dev Internal function to get order hash.
     *
     * Requirements:
     * - @param order - object of an order.
     * 
     * @return bytes32 - hash value.
     */
    function _genHashKey(Order memory order) internal pure returns(bytes32) {
        bytes32 hashKey = keccak256(
            abi.encode(order.seller, order.tokenAddress, order.tokenId, order.currencyAddress, order.price, order.nonce)
        );
        return hashKey;
    }

    /**
     * @dev Internal function to get loan hash.
     *
     * Requirements:
     * @param bid - bid object.
     * 
     * @return bytes32 - hash value.
     */
    function _genBidHash(Bid memory bid) internal pure returns(bytes32) {
        return keccak256(
            abi.encode(BID_TYPEHASH, bid.to, bid.amount, bid.currency, bid.quantity, bid.tokenAddress, bid.tokenId)
        );
    }

}
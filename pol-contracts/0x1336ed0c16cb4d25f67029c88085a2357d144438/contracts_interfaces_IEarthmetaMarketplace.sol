// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.9;

/// @title Errors contract.
/// @author Errors 2024.
abstract contract Errors {
    error PriceNotMet(address nftAddress, uint256 tokenId, uint256 price);
    error ItemNotForSale(address nftAddress, uint256 tokenId);
    error NotListed(address nftAddress, uint256 tokenId);
    error AlreadyListed(address nftAddress, uint256 tokenId);
    error NoProceeds();
    error NotNftOwner();
    error NotApprovedForMarketplace();
    error PriceMustBeAboveZero();
    error NftAddressNotAllowed(address nftAddress);
}

/// @title IEarthmetaMarketplace interface.
/// @author IEarthmetaMarketplace 2024.
interface IEarthmetaMarketplace {
    /// @notice Listing struct.
    /// @param seller the seller address.
    /// @param tokenAddress the token required to buy the token.
    /// @param priceUSD the price in usd
    struct Listing {
        address seller;
        address tokenAddress;
        uint256 priceUSD;
    }

    /// @notice emit when user list an item.
    /// @param seller the seller address.
    /// @param nftAddress the ERC721 address.
    /// @param tokenId the token id.
    /// @param priceUSD the price in usd
    event ItemListed(
        address seller,
        address indexed nftAddress,
        uint256 tokenId,
        uint256 priceUSD
    );

    /// @notice emit when user cancel a listing.
    /// @param seller the seller address.
    /// @param nftAddress the ERC721 address.
    /// @param tokenId the token id.
    /// @param priceUSD the price in usd
    event ItemCanceled(address indexed seller, address indexed nftAddress, uint256 indexed tokenId, uint256 priceUSD);

    /// @notice emit when user update a listing.
    /// @param seller the seller address.
    /// @param nftAddress the ERC721 address.
    /// @param tokenId the token id.
    /// @param priceUSD the price in usd
    event ItemUpdated(address indexed seller, address indexed nftAddress, uint256 indexed tokenId, uint256 priceUSD);

    /// @notice emit when user buy an item.
    /// @param buyer the buyer address.
    /// @param nftAddress the ERC721 address.
    /// @param tokenId the token id.
    /// @param tokenAddress the token required to buy the token.
    /// @param price the price.
    /// @param netPrice price after fees.
    event ItemBought(
        address buyer,
        address indexed nftAddress,
        uint256 tokenId,
        address tokenAddress,
        uint256 price,
        uint256 netPrice
    );

    /// @notice emit when user buy an item.
    /// @param index the buyer address.
    /// @param receiver the receiver address.
    /// @param nftAddress the ERC721 address.
    /// @param tokenId the token id.
    /// @param tokenAddress the token required to buy the token.
    /// @param fee the amount of fee.
    event ItemFee(
        uint256 index,
        address receiver,
        address indexed nftAddress,
        uint256 tokenId,
        address tokenAddress,
        uint256 fee
    );

    /// @notice emit when new token address is set.
    /// @param tokenAddress the token required to buy the token.
    /// @param status is the token active.
    event SetToken(address tokenAddress, bool status);

    /// @notice emit when new nft address is set.
    /// @param nftAddress the token required to buy the token.
    /// @param status is the token active.
    event SetNftAddress(address nftAddress, bool status);

    /// @notice Clean listing, this function can be called to remove the nft from listing when it's transfered to another user.
    /// @param _tokenId The token id.
    function cleanListing(uint256 _tokenId) external;
}
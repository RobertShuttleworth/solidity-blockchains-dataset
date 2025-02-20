// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.9;

interface IEarthmetaErrors {
    error CallerNotGateway();
    error CityAlreadyMinted();
    error CountryNotFound();
    error CityLevelZero();
    error CityUriEmpty();
    error CityNotFound();
    error NotEarthmetaCity();
    error NotEarthmetaLand();
    error InvalidRoyaltiesNftAddress();
    error LandAlreadyMinted();
    error LandUriEmpty();
}

interface VaultErrors {
    error InvalidAttachedValue(uint256 submitted, uint256 required);
    error InvalidMerchantSignature(address signer, address merchant);
    error MerchantCanNotBeReceiver();
    error CallMustBeReceiver();
    error InvalidChainId(uint256, uint256);
    error InvalidToken(address);
    error CityAlreadyMinted(uint256);
    error LandAlreadyMinted(uint256);
    error ExpiredRequest(uint256, uint256);
}

interface TransferErrors {
    error ErrorToSendFees(address receiver);
}
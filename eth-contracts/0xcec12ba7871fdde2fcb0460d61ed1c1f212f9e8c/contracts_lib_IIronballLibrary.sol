// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.21;

struct ActionData {
    address nftAddress;
    uint256[] tokenIds;
    address by;
    Action action;
}

library IronballLibrary {
    struct MintConfig {
        uint128 mintPrice;
        uint64 lockPeriod;
        uint24 maxMintsPerTransaction;
        uint24 maxMintsPerWallet;
        bool active;
    }
}

enum Action {UPGRADE, REFUND}
enum Color {DIAMOND, GOLD, SILVER, BRONZE, IRON}
struct CollectionData {
    address owner;
    address collectionAddress;
    address collectionImplementation;
    string name;
    string symbol;
    uint256 maxSupply;
    string baseUri;
    string preRevealImageURI;
    address referrer;
    address whitelistSigner;
    IronballLibrary.MintConfig publicMintConfig;
    IronballLibrary.MintConfig privateMintConfig;
    address minter;  // New field to track mint status
    uint24 quantity;
    uint256[] mintedTokens;
    Color[] tokenColor;
}
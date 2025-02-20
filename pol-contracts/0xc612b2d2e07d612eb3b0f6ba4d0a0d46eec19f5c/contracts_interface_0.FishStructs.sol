// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

    struct Fish_CERTNFT_Metadata {
        // Since this is a DOT we keep track of who is the current owner of the NFT
        //   this is nice for other on chain stuff for users
        //   also relates to the contractRewardDistributor concept
        address currentOwner;

        uint256 packageID;
        // reward distribution power
        uint256 power;
        // minting price
        uint256 mintingPrice;
        uint256 mintingBonanzaRow;


        //is Whale
        bool isWhale;
        //Vesting duration
        uint256 vestingduration;

        // // points to the IPFS metadata for this NFT
        // //   this can be changed
        // //   new token metadata should reference old token metdata, and the transaction that caused the change
        string tokenIPFSURI;

    }

    struct Fish_Package_Data {
        uint256 packageType;
        string packageName;
        string packageDisplayName;

        uint256 power;
        string initialIPFSURI;
    
        uint256 basePrice;
        uint256 incrementPrice;
        uint256 maxPerBonanzaLine;
        uint256 maxMint;

        string targetPortal;

        bool isWhale;
        uint256 vestingDuration;
    }

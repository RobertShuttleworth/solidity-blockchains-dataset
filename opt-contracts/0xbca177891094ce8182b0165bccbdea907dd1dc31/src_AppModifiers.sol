// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import {AppStorageRoot, Village} from "./src_AppStorage.sol";
import {LibDiamond} from "./src_diamond_libraries_LibDiamond.sol";

// import {VillagersLibrary} from "./libraries/VillagersLibrary.sol";

contract AppModifiers is AppStorageRoot {
    error NotVillageOwner();
    error UserNoAccessToMint();
    error PlayerHasNotRevealedAttack();
    error VillageAlreadyRazed();
    error NotForwardFireAddress();
    error AlreadyMintedVillage();
    error NoAccess();
    error NotGotchiOwner();
    error GotchiAlreadyDead();

    modifier onlyOwner() {
        LibDiamond.enforceIsContractOwner();
        _;
    }

    modifier onlyOwnerOrHand3() {
        if (
            msg.sender != LibDiamond.diamondStorage().contractOwner &&
            msg.sender != address(0x6F725cacFfc6A540Ee0E26A7bA79AD34Cc5a4b5F)
        ) {
            revert NoAccess();
        }
        _;
    }

    modifier onlyVillageOwner(uint256 _tokenId) {
        if (s.tokenIdToVillage[_tokenId].owner != msg.sender) {
            revert NotVillageOwner();
        }
        _;
    }

    modifier onlyMinter() {
        if (!s.addressToCanMint[msg.sender]) {
            revert UserNoAccessToMint();
        }
        _;
    }

    modifier onlyMintOne() {
        uint256 tokenId = s.addressToTokenId[msg.sender];
        if (tokenId != 0) {
            Village memory village = s.tokenIdToVillage[tokenId];
            //if the village they have is not razed and still alive
            if (block.timestamp - village.timeFireLastStoked < 3 days) {
                revert AlreadyMintedVillage();
            }
        }
        _;
    }

    modifier onlyPlayersThatHaveRevealed(uint256 _tokenId) {
        if (s.tokenIdToVillage[_tokenId].attackedByVillageIds.length > 0) {
            revert PlayerHasNotRevealedAttack();
        }
        _;
    }

    modifier onlyNonRazedVillages(uint256 _tokenId) {
        if (s.tokenIdToVillage[_tokenId].timeRazed != 0) {
            revert VillageAlreadyRazed();
        }
        _;
    }

    modifier onlyForwardFire() {
        if (s.forwardFireAddress != msg.sender) {
            revert NotForwardFireAddress();
        }
        _;
    }

    modifier onlyGotchiOwner(uint256 _tokenId) {
        if (s.tokenIdToGotchi[_tokenId].owner != msg.sender) {
            revert NotGotchiOwner();
        }
        _;
    }

    modifier onlyNonDeadGotchis(uint256 _tokenId) {
        if (s.tokenIdToGotchi[_tokenId].isDead) {
            revert GotchiAlreadyDead();
        }
        _;
    }
}
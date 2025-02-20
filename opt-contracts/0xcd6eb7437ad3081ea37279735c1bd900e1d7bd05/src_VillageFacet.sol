// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import {AppStorageRoot, Village, VillageReward} from "./src_AppStorage.sol";
import {AppModifiers} from "./src_AppModifiers.sol";
import {console} from "./lib_forge-std_src_Test.sol";
import {IStokeFire} from "./src_nfts_IStokeFire.sol";
import {RewardLibrary} from "./src_libraries_RewardLibrary.sol";
import {VillagersLibrary} from "./src_libraries_VillagersLibrary.sol";
import {WoodLibrary} from "./src_libraries_WoodLibrary.sol";
import "./lib_openzeppelin-contracts_contracts_token_ERC721_ERC721.sol";

interface IStokeFireNFT {
    function mint(address _a) external returns (uint256);

    function burn(uint256 _tokenId) external;
}

contract VillageFacet is AppModifiers, IStokeFire {
    event MintVillage(uint256 id, address owner, string name);
    event VillageTransfered(uint256 id, address from, address to);
    event SetVillageDataForTesting(
        uint256 tokenId,
        uint256 food,
        uint256 wood,
        uint256 huts,
        uint256 villagers,
        uint256 score,
        uint32 level
    );

    error NotADayOfHisotryOnChain();
    error NoTransfersCurrently();

    function mint(string calldata name) external onlyMinter onlyMintOne {
        IStokeFireNFT stokeFireNFT = IStokeFireNFT(s.stokeFireNFTAddress);
        uint256 tokenId = stokeFireNFT.mint(msg.sender);
        VillagersLibrary.initVillage(tokenId, name);
        s.addressToTokenId[msg.sender] = tokenId; //keep track of this addresses village
        emit MintVillage(tokenId, msg.sender, name);
    }

    function getCanMint(address _a) external view returns (bool) {
        return s.addressToCanMint[_a];
    }

    function redeemRewards(
        uint256 _tokenId
    )
        external
        onlyVillageOwner(_tokenId)
        onlyNonRazedVillages(_tokenId)
        onlyPlayersThatHaveRevealed(_tokenId)
    {
        RewardLibrary.redeemRewards(_tokenId, msg.sender, false);
    }

    function onReceive(uint256 value) external onlyForwardFire {
        RewardLibrary.onReceive(value);
    }

    //// admin ////

    function setFireAddress(address _a) external onlyOwner {
        s.fireAddress = _a;
    }

    function setStokeFireNFTAddress(address _a) external onlyOwner {
        s.stokeFireNFTAddress = _a;
    }

    function setForwardFireAddress(address _a) external onlyOwner {
        s.forwardFireAddress = _a;
    }

    function setMinter(address _a, bool _canMint) external onlyOwnerOrHand3 {
        s.addressToCanMint[_a] = _canMint;
    }

    //only used in testing purposes
    function setVillageDataForTesting(
        bool isEmit,
        uint256 _tokenId,
        uint256 _food,
        uint256 _wood,
        uint256 _huts,
        uint256 _villagers,
        uint256 _score,
        uint32 _level
    ) external onlyOwner {
        RewardLibrary.updateEthOwed(_tokenId);

        Village storage village = s.tokenIdToVillage[_tokenId];
        uint256 oldScore = village.score;
        village.food = _food;
        village.wood = _wood;
        village.huts = _huts;
        village.villagers = _villagers;
        village.score = _score;
        village.level = _level;

        RewardLibrary.updateDebt(_tokenId);

        if (village.score > oldScore) {
            s.totalVillageScore += village.score - oldScore;
        } else if (village.score < oldScore) {
            uint256 decrease = oldScore - village.score;
            s.totalVillageScore = decrease > s.totalVillageScore
                ? 0
                : s.totalVillageScore - decrease;
        }

        if (isEmit) {
            //does not take into account totalVillageScore yet
            emit SetVillageDataForTesting(
                _tokenId,
                _food,
                _wood,
                _huts,
                _villagers,
                _score,
                _level
            );
        }
    }

    //Overrides for StokeFireNFT

    function tokenURI(
        uint256 id
    ) external view override returns (string memory) {
        return
            "https://arweave.net/PkIY_7uHWl9KAbDRkKI3v-zwhF_vYdkVhM07CferIzU";
    }

    function beforeTransfer(
        address _from,
        address _to,
        uint256 _tokenId
    ) external override {
        //No transfers to start out.
        //in the future may allow transfers for those that are already playing the game
        revert NoTransfersCurrently();
    }

    function afterTransfer(
        address _from,
        address _to,
        uint256 _tokenId
    ) external override {
        s.tokenIdToVillage[_tokenId].owner = _to; //update owner of the data
        emit VillageTransfered(_tokenId, _from, _to);
    }

    //// GETTERS ////

    function getVillage(
        uint256 _tokenId
    ) external view returns (Village memory) {
        return s.tokenIdToVillage[_tokenId];
    }

    function getStokeFireNFTAddress() external view returns (address) {
        return s.stokeFireNFTAddress;
    }

    function getForwardFireAddress() external view returns (address) {
        return s.forwardFireAddress;
    }

    function getTotalVillageScore() external view returns (uint256) {
        return s.totalVillageScore;
    }

    function getEthOwed(uint256 _tokenId) external view returns (uint256) {
        VillageReward storage vr = s.tokenIdToVillageReward[_tokenId];
        return vr.ethOwed;
    }

    function getWood(uint256 _tokenId) external view returns (uint256) {
        return WoodLibrary.getWood(_tokenId);
    }

    function pendingEth(uint256 _tokenId) external view returns (uint256) {
        return RewardLibrary.pendingEthHelper(_tokenId);
    }
}
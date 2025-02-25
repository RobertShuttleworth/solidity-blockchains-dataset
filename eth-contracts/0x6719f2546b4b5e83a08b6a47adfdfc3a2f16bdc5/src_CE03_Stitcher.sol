// SPDX-License-Identifier: MIT
pragma solidity ^0.8.22;

import "./lib_openzeppelin-contracts_contracts_access_Ownable.sol";
import "./lib_openzeppelin-contracts_contracts_utils_Base64.sol";
import "./src_CE01_Helper.sol";
import "./src_ICE00_Structs.sol";

interface ITraitGenerator {
    function generateTraits(uint128 rand, uint256 entropy, uint128 peace, uint128 collective) 
        external view returns (Structs.TreeDetails memory, Structs.CorpseDetails memory, string[9] memory);
}

interface IArtFactory {
    function buildAssets(uint128 rand, uint256 entropy, uint128 peace, uint128 collective, string[9] memory palette) 
        external view returns (bytes memory);
}

interface ICorpse {
    function drawCorpses(Structs.CorpseDetails memory corpse_deets, string[9] memory palette) 
        external pure returns (string memory);
}

interface ITreeMaster {
    function drawTree(Structs.TreeDetails memory tree_deets, string[9] memory palette) 
        external view returns (string memory mainArt, string memory image);
}

interface IMetadataGenerator {
    function buildFullMeta(uint256 entropy, uint128 peace, uint128 collective, string[9] memory palette, Structs.CorpseDetails memory corpse_deets, Structs.TreeDetails memory tree_deets) 
        external pure returns (string memory);
}

contract Stitcher is Ownable, Helper, Structs {
    using Base64 for bytes;

    ITraitGenerator public traitGenerator;
    IArtFactory public artFactory;
    ICorpse public corpseGenerator;
    ITreeMaster public treeGenerator;
    IMetadataGenerator public metadataGenerator;

    constructor(
        address initialOwner,
        address _traitGenerator,
        address _artFactory,
        address _corpseGenerator,
        address _treeGenerator,
        address _metadataGenerator
    ) Ownable(initialOwner) {
        traitGenerator = ITraitGenerator(_traitGenerator);
        artFactory = IArtFactory(_artFactory);
        corpseGenerator = ICorpse(_corpseGenerator);
        treeGenerator = ITreeMaster(_treeGenerator);
        metadataGenerator = IMetadataGenerator(_metadataGenerator);
    }

    // Setter functions
    function setTraitGenerator(address _traitGenerator) external onlyOwner {
        traitGenerator = ITraitGenerator(_traitGenerator);
    }

    function setArtFactory(address _artFactory) external onlyOwner {
        artFactory = IArtFactory(_artFactory);
    }

    function setCorpseGenerator(address _corpseGenerator) external onlyOwner {
        corpseGenerator = ICorpse(_corpseGenerator);
    }

    function setTreeGenerator(address _treeGenerator) external onlyOwner {
        treeGenerator = ITreeMaster(_treeGenerator);
    }

    function setMetadataGenerator(address _metadataGenerator) external onlyOwner {
        metadataGenerator = IMetadataGenerator(_metadataGenerator);
    }

    // Optimized to get all data in one call
    function getAllTokenData(uint128 rand, uint256 entropy, uint128 peace, uint128 collective) 
        internal view returns (
            TreeDetails memory tree_deets,
            CorpseDetails memory corpse_deets,
            string[9] memory palette,
            bytes memory otherAssets,
            string memory corpseAsset,
            string memory treeMainArt,
            string memory treeImage
        ) 
    {
        // Get traits once
        (tree_deets, corpse_deets, palette) = traitGenerator.generateTraits(rand, entropy, peace, collective);
        
        // Get all assets in parallel
        otherAssets = artFactory.buildAssets(rand, entropy, peace, collective, palette);
        corpseAsset = corpseGenerator.drawCorpses(corpse_deets, palette);
        (treeMainArt, treeImage) = treeGenerator.drawTree(tree_deets, palette);
    }


    // Main function to generate complete tokenURI with single trait generation
    function generateTokenURI(uint256 tokenId, uint128 rand, uint256 entropy, uint128 peace, uint128 collective) 
        public view returns (string memory) 
    {
        (
            TreeDetails memory tree_deets,
            CorpseDetails memory corpse_deets,
            string[9] memory palette,
            bytes memory otherAssets,
            string memory corpseAsset,
            string memory treeMainArt,
            string memory treeImage
        ) = getAllTokenData(rand, entropy, peace, collective);

        // Build animation URL content
        string memory mainArt = string(abi.encodePacked(
            otherAssets, 
            corpseAsset, 
            treeMainArt, 
            "</script></body></html>"
        ));

        return string(abi.encodePacked(
            "data:application/json;utf8,",
            '{"name":"Crimson Echo #',
            uint2str(tokenId),
            '","description":"Crimson Echo is a generative film generated by and stored fully on Ethereum, exploring how stories emerge through permanent acts of individual and collective conscience.","image": "data:image/svg+xml;base64,',
            Base64.encode(bytes(treeImage)),
            '","animation_url":"data:text/html;base64,', Base64.encode(bytes(mainArt)),
            '",',
            metadataGenerator.buildFullMeta(entropy, peace, collective, palette, corpse_deets, tree_deets)
            )
        );
    }

    function getMetadata(uint128 rand, uint256 entropy, uint128 peace, uint128 collective) 
        public view returns (string memory) 
    {
        (TreeDetails memory tree_deets, CorpseDetails memory corpse_deets, string[9] memory palette,,,,) = 
            getAllTokenData(rand, entropy, peace, collective);
        return metadataGenerator.buildFullMeta(entropy, peace, collective, palette, corpse_deets, tree_deets);
    }

    function getImage(uint128 rand, uint256 entropy, uint128 peace, uint128 collective) 
        public view returns (string memory) 
    {
        (,,,,,, string memory treeImage) = getAllTokenData(rand, entropy, peace, collective);
        return treeImage;
    }

    function getAnimationUrl(uint128 rand, uint256 entropy, uint128 peace, uint128 collective) 
        public view returns (string memory) 
    {
        (,,, bytes memory otherAssets, string memory corpseAsset, string memory treeMainArt,) = 
            getAllTokenData(rand, entropy, peace, collective);

        string memory mainArt = string(abi.encodePacked(
            otherAssets, 
            corpseAsset, 
            treeMainArt, 
            "</script></body></html>"
        ));
        return mainArt;
    }
}
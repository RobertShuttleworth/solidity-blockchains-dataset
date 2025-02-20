// SPDX-License-Identifier: MIT
pragma solidity ^0.8.22;

import "./lib_openzeppelin-contracts_contracts_utils_Base64.sol";
import "./src_CE01_Helper.sol";
import "./src_ICE00_Structs.sol";

contract MetadataBuilder is Helper, Structs {
        
    using Base64 for bytes;
    
    function buildMetaTree(TreeDetails memory tree_deets)
    internal pure returns (string memory) {
        return string(abi.encodePacked(
            '"},{"trait_type":"Trunk1 lines","value":"',
            uint2str(tree_deets.trunk1deets.num_lines),
            '"},{"trait_type":"Trunk1 height","value":"',
            uint2str(tree_deets.trunk1deets.height),
            '"},{"trait_type":"Trunk2 branches","value":"',
            uint2str(tree_deets.trunk2deets.num_branches),
            '"},{"trait_type":"Trunk2 root","value":"',
            uint2str(tree_deets.trunk2deets.root_distance),
            '"},{"trait_type":"Trunk2 height","value":"',
            uint2str(tree_deets.trunk2deets.max_y),
            '"},{"trait_type":"Leaf fluff","value":"',
            uint2str(tree_deets.leaf_deets.fluff)
        ));
    }

    function buildMetaCorpse(CorpseDetails memory corpse_deets)
    internal pure returns (string memory) {
        return string(abi.encodePacked(
            '"},{"trait_type":"Corpse Shapes","value":"',
            uint2str(corpse_deets.num_shapes),
            '"},{"trait_type":"Corpse Glow","value":"',
            uint2str(corpse_deets.glow)
        ));
    }

    function buildFullMeta(uint256 entropy, uint128 peace, uint128 collective, string[9] memory palette, CorpseDetails memory corpse_deets, TreeDetails memory tree_deets)
    external pure returns (string memory) {
        return string(abi.encodePacked(
            '"attributes":[{"trait_type":"Palette","value":"',
            palette[0],
            '"},{"trait_type":"Entropy","value":"',
            uint2str(entropy),
            '"},{"trait_type":"Peace","value":"',
            uint2str(uint256(peace)),
            '"},{"trait_type":"Collective","value":"',
            uint2str(uint256(collective)),
            buildMetaCorpse(corpse_deets),
            buildMetaTree(tree_deets),
            '"}]}'
        ));
    }
}
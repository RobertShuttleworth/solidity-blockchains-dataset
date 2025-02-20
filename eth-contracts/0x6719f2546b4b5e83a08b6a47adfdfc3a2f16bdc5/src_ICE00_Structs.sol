// SPDX-License-Identifier: MIT
pragma solidity ^0.8.22;

interface Structs {

    struct CorpseDetails{
        uint256 seed;
        uint256 max_opacity;
        uint256 max_size;
        uint256 max_complexity;
        uint256 num_shapes;
        uint256 crowd;
        string stroke;
        uint8 glow;
    }

    struct Trunk1Details {
        uint256 num_lines;
        uint256 stroke;
        uint256 height;
        uint256 curve;
    }

    struct Trunk2Details {
        uint256 num_branches;
        uint256 num_lines;
        uint256 stroke;
        uint256 convergance;
        uint256 curvature;
        uint256 root_distance;
        string iteration;
        uint256 max_x;
        uint256 max_y;
    }

    struct LeafDetails {
        uint256 num_leaves;
        uint256 maxx;
        uint256 maxy;
        uint256 fluff;
    }

    struct TreeDetails {
        uint256 seed;
        uint256 entropy;
        uint256 collective;
        Trunk1Details trunk1deets;
        Trunk2Details trunk2deets;
        LeafDetails leaf_deets;
    }
}
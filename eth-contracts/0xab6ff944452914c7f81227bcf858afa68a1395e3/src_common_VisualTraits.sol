// SPDX-License-Identifier: MIT
pragma solidity ^0.8.21;

/**
 * @author Eto Vass
 */

enum FigureCollection {
    CIRCLE,
    TRIANGLE,
    SQUARE,
    PENTAGON,
    HEXAGON,
    BULL,
    SKULL,
    CAT,
    CHAIN,
    ETH,
    BTC,
    SNOWFLAKE,
    GEOMETRY,
    STARS,
    CRYPTO
}

enum WrapType {
    NONE,
    SQUARE,
    SQUARE_45,
    HEXAGON,
    HEXAGON_30,
    CIRCLE
}

struct VisualTraits {
    FigureCollection figureCollection;
    WrapType wrapType;
}
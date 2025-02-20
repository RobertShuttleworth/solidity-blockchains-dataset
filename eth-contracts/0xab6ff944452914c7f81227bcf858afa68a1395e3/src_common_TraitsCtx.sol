// SPDX-License-Identifier: MIT
pragma solidity ^0.8.21;

import { RandomCtx } from './src_common_Random.sol';
import { VisualTraits } from './src_common_VisualTraits.sol';

/**
 * @author Eto Vass
 */

struct PuzzleData {
    uint8 numFigures;
    uint8 rows;
    uint8 cols;
}

struct TraitsCtx {
    VisualTraits visualTraitsForGenerated;
    uint8 maxFigures;

    PuzzleData puzzleData;

    RandomCtx rndCtx;
}
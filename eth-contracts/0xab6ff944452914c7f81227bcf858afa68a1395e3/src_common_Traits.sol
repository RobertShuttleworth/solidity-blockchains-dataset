// SPDX-License-Identifier: MIT
pragma solidity ^0.8.21;

import './src_common_Random.sol';
import './src_common_TraitsCtx.sol';
import { VisualTraits, FigureCollection, WrapType } from './src_common_VisualTraits.sol';
import { Utils } from './src_common_Utils.sol';
import { DynamicBuffer } from './src_common_DynamicBuffer.sol';

/**
 * @author Eto Vass
 */

library Traits {
    function generateTraitsCtx(RandomCtx memory rndCtx) internal pure returns (TraitsCtx memory) {
        TraitsCtx memory result;

        result.rndCtx = rndCtx;
        
        result.visualTraitsForGenerated = generateVisualTraits(rndCtx); 
        
        result.maxFigures = 6;
        result.puzzleData.rows = 6;
        result.puzzleData.cols = 6;

        return result;
    }

    function generateVisualTraits(RandomCtx memory rndCtx) internal pure returns (VisualTraits memory) {
        VisualTraits memory result;

        uint16[] memory figP = new uint16[](15);
        figP[0] = 10;
        figP[1] = 10;
        figP[2] = 10;
        figP[3] = 10;
        figP[4] = 8;
        figP[5] = 7;
        figP[6] = 7;
        figP[7] = 6;
        figP[8] = 5;
        figP[9] = 4;
        figP[10] = 4;
        figP[11] = 4;
        figP[12] = 3;
        figP[13] = 3;
        figP[14] = 3;

        result.figureCollection = FigureCollection(Random.randWithProbabilities(rndCtx, figP));

        uint16[] memory wrapP = new uint16[](6);
        wrapP[0] = 10;
        wrapP[1] = 10;
        wrapP[2] = 10;
        wrapP[3] = 8;
        wrapP[4] = 7;
        wrapP[5] = 5;

        if (result.figureCollection == FigureCollection.ETH || result.figureCollection == FigureCollection.CHAIN) {
            // these looks better  wrapped, thus decrease the probability of no wrap
            wrapP[0] = 1;
        }

        result.wrapType = WrapType(Random.randWithProbabilities(rndCtx, wrapP));

        return result;
    }

    function stringTrait(string memory traitName, string memory traitValue) internal pure returns (bytes memory) {
        return bytes(string.concat('{"trait_type":"', traitName,'","value":"',traitValue, '"}'));
    }

    function toString(FigureCollection figureCollection) internal pure returns (string memory) {
        if (figureCollection == FigureCollection.CIRCLE) {
            return "circle";
        } else if (figureCollection == FigureCollection.TRIANGLE) {
            return "triangle";
        } else if (figureCollection == FigureCollection.SQUARE) {
            return "square";
        } else if (figureCollection == FigureCollection.PENTAGON) {
            return "pentagon";
        } else if (figureCollection == FigureCollection.HEXAGON) {
            return "hexagon";
        } else if (figureCollection == FigureCollection.BULL) {
            return "bull";
        } else if (figureCollection == FigureCollection.SKULL) {
            return "skull";
        } else if (figureCollection == FigureCollection.CAT) {
            return "cat";
        } else if (figureCollection == FigureCollection.CHAIN) {
            return "chain";
        } else if (figureCollection == FigureCollection.ETH) {
            return "eth";
        } else if (figureCollection == FigureCollection.BTC) {
            return "btc";
        } else if (figureCollection == FigureCollection.SNOWFLAKE) {
            return "snowflake";
        } else if (figureCollection == FigureCollection.GEOMETRY) {
            return "geometry";
        } else if (figureCollection == FigureCollection.STARS) {
            return "stars";
        } else if (figureCollection == FigureCollection.CRYPTO) {
            return "crypto";
        }
    }

    function toString(WrapType wrapType) internal pure returns (string memory) {
        if (wrapType == WrapType.NONE) {
            return "none";
        } else if (wrapType == WrapType.SQUARE) {
            return "square";
        } else if (wrapType == WrapType.SQUARE_45) {
            return "square_45";
        } else if (wrapType == WrapType.HEXAGON) {
            return "hexagon";
        } else if (wrapType == WrapType.HEXAGON_30) {
            return "hexagon_30";
        } else if (wrapType == WrapType.CIRCLE) {
            return "circle";
        }
    }

    function getTraitsAsJson(TraitsCtx memory traitsCtx) internal pure returns (string memory) {
        bytes memory buffer = DynamicBuffer.allocate(4096);
        
        Utils.concat(buffer, 
            stringTrait("rows", Utils.toString(traitsCtx.puzzleData.rows)),',',
            stringTrait("cols", Utils.toString(traitsCtx.puzzleData.cols)),',',
            stringTrait("figure collection", toString(traitsCtx.visualTraitsForGenerated.figureCollection)),',',
            stringTrait("wrap type", toString(traitsCtx.visualTraitsForGenerated.wrapType))
        );

        return string(buffer);
    }
}
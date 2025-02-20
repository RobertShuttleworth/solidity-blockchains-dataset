// SPDX-License-Identifier: MIT
pragma solidity ^0.8.21;

import { IPathsManager, Figure } from './src_interfaces_IPathsManager.sol';
import { FiguresPathLib } from './src_figures_FigurePaths.sol';
import { IAssetsSSTORE2 } from './src_interfaces_IAssetsSSTORE2.sol';
import { BoundingBox, Point } from './src_common_Lib2D.sol';
import { RandomCtx } from './src_common_Random.sol';
import { FigureCollection, WrapType } from './src_common_VisualTraits.sol';
import { DynamicBuffer } from './src_common_DynamicBuffer.sol';
import { OutlineCtx } from './src_figures_FigurePaths.sol';

/**
 * @author Eto Vass
 */

contract PathsManager is IPathsManager {
    IAssetsSSTORE2 public assetsSSTORE2;

    constructor(IAssetsSSTORE2 _assetsSSTORE2) {
        assetsSSTORE2 = _assetsSSTORE2;
    }

    function getFigureCollection(RandomCtx memory rndCtx, FigureCollection collection, uint numFigures) external view returns (Figure[] memory figures, bool areDifferent) {
        return FiguresPathLib.getFigureCollection(rndCtx, collection, numFigures, assetsSSTORE2);
    }

    function getStoneFigure() external view returns (Figure memory figure) {
        return FiguresPathLib.getStoneFigure(assetsSSTORE2);
    }

    function getWrapFigure(WrapType wrapType, int cx, int cy) external view returns (string memory svgPath, BoundingBox memory bbox) {
        bytes memory outlineBuffer = DynamicBuffer.allocate(2000);

        if (wrapType != WrapType.NONE) {
            if (wrapType == WrapType.SQUARE) {
                (svgPath, bbox) = FiguresPathLib.outline(outlineBuffer, OutlineCtx(cx, cy, 4, 1000, 180, 45, false), "wrap");
            } else if (wrapType == WrapType.SQUARE_45) {
                (svgPath, bbox) = FiguresPathLib.outline(outlineBuffer, OutlineCtx(cx, cy, 4, 1000, 180, 0, false), "wrap");
            } else if (wrapType == WrapType.HEXAGON) {
                (svgPath, bbox) = FiguresPathLib.outline(outlineBuffer, OutlineCtx(cx, cy, 6, 1000, 180, 0, false), "wrap");
            } else if (wrapType == WrapType.HEXAGON_30) {
                (svgPath, bbox) = FiguresPathLib.outline(outlineBuffer, OutlineCtx(cx, cy, 6, 1000, 180, 30, false), "wrap");
            } else if (wrapType == WrapType.CIRCLE) {
                string memory size2 = "1000";
                svgPath = string.concat('<circle id="wrap" cx="', size2, '" cy="', size2, '" r="', size2, '"/>');
                bbox = BoundingBox(Point(0,0), Point(2000, 2000));
            }
        }

        return (svgPath, bbox);
    }
}
//SPDX-License-Identifier: MIT
pragma solidity ^0.8.21;

import { FigureCollection, WrapType } from './src_common_VisualTraits.sol';
import { IAssetsSSTORE2 } from './src_interfaces_IAssetsSSTORE2.sol';  
import { RandomCtx } from './src_common_Random.sol';
import { BoundingBox } from './src_common_Lib2D.sol';

struct Figure {
    string svgPath;
    BoundingBox bbox;
    int offsetY;
    int padding;
    bytes id;
    int percentIncrease;
}

interface IPathsManager {
    function getFigureCollection(RandomCtx memory rndCtx, FigureCollection collection, uint numFigures) external view returns (Figure[] memory figures, bool areDifferent);

    function getStoneFigure() external view returns (Figure memory figure);

    function getWrapFigure(WrapType wrapType, int cx, int cy) external view returns (string memory svgPath, BoundingBox memory bbox);
}
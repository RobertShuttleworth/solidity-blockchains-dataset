// SPDX-License-Identifier: MIT
pragma solidity ^0.8.21;

import { Utils } from './src_common_Utils.sol';
import { Random, RandomCtx } from './src_common_Random.sol';
import { Division } from './src_common_Division.sol';
import { BoundingBox, Point, Lib2D } from './src_common_Lib2D.sol';
import { Color } from './src_common_Color.sol';
import { Svg } from './src_common_SVG.sol';
import { Gradients } from './src_game-renderer_Gradients.sol';
import { Figure, IPathsManager } from './src_interfaces_IPathsManager.sol';
import { Palettes } from './src_game-renderer_Palettes.sol';
import { DynamicBuffer } from './src_common_DynamicBuffer.sol';

import { WrapType, FigureCollection } from './src_common_VisualTraits.sol';
import { Filters } from './src_game-renderer_Filters.sol';
import { TraitsCtx } from './src_common_TraitsCtx.sol';
import { IAssetsSSTORE2 } from './src_interfaces_IAssetsSSTORE2.sol';

/**
 * @author Eto Vass
 */

struct FigureByPathCtx {
    string id;
    int cx;
    int cy;
    Figure figure;
    Color.Hsl color;
    WrapType wrapType;
}

struct AllPathNodesCtx {
    string id;
    string pathId;
    string savedPathId; 
    BoundingBox bb;
    BoundingBox savedBBox; 
    Color.Hsl color; 
    WrapType wrapType;
    int offsetY;
    int padding;
    int percentIncrease;
}

library FigureGenerator {
    function createFigures(bytes memory buffer, RandomCtx memory rndCtx, TraitsCtx memory traits, IPathsManager pathsManager) internal view {
        Color.Hsl memory color;
        Color.Hsl[] memory palette;
        
        palette = Palettes.getPalette(rndCtx, traits.maxFigures);

        Utils.concat(buffer, bytes(Filters.createDropShadowFilter()));

        (Figure[] memory figures, bool areDifferent) = pathsManager.getFigureCollection(rndCtx, traits.visualTraitsForGenerated.figureCollection, traits.maxFigures);
        (string memory wrapSvgPath, BoundingBox memory wrapBBox) = pathsManager.getWrapFigure(traits.visualTraitsForGenerated.wrapType, 1000, 1000);
        // generate stone figure
        Figure memory stoneFigure = pathsManager.getStoneFigure();

        addPathsToDefs(buffer, figures, stoneFigure, wrapSvgPath, areDifferent);


        for (uint8 i=0; i<traits.maxFigures; i++) {

            color = palette[i];

            string memory idStr = string.concat("fig-", Utils.toString(i + 1));
            generateFigureByPath(buffer, FigureByPathCtx(idStr, 1000, 1000, figures[i], color, traits.visualTraitsForGenerated.wrapType), "wrap", wrapBBox);
        }

        

        color = Color.Hsl(0, 0, 90);
        //color = palette[0];
        generateFigureByPath(buffer, FigureByPathCtx("fig--1", 1000, 1000, stoneFigure, color, traits.visualTraitsForGenerated.wrapType), "wrap", wrapBBox);
    }

    function addPathsToDefs(bytes memory buffer, Figure[] memory figures, Figure memory stoneFigure, string memory wrapSvgPath, bool areDifferent) private pure {
        Utils.concat(buffer, '<defs>');
        
        Utils.concat(buffer, bytes(stoneFigure.svgPath));
        for (uint8 i=0; i<figures.length; i++) {
            Utils.concat(buffer, bytes(figures[i].svgPath));
            if (!areDifferent) {
                break;
            }
        }

        Utils.concat(buffer, bytes(wrapSvgPath));
        Utils.concat(buffer, '</defs>');
    }

    function drawBBox(BoundingBox memory bb) private pure returns (string memory) {
        int width;
        int height;

        (width, height) = Lib2D.getWidthHeight(bb);
        
        return Svg.rect(
            string.concat(
                Svg.prop("x", Utils.toString(bb.p1.x)),
                Svg.prop("y", Utils.toString(bb.p1.y)),
                Svg.prop("width", Utils.toString(width)),
                Svg.prop("height", Utils.toString(height)),
                Svg.prop("fill", "orange")
            ), "");
    }


    function generateFigureByPath(bytes memory buffer, FigureByPathCtx memory fctx, string memory wrapSvgPathId, BoundingBox memory wrapBBox) private pure {
        string memory savedPathId = string(fctx.figure.id);
        BoundingBox memory savedBBox = Lib2D.cloneBoundingBox(fctx.figure.bbox);

        if (fctx.wrapType != WrapType.NONE) {
            fctx.figure.id = bytes(wrapSvgPathId);
            fctx.figure.bbox = wrapBBox;
        }

        int width;
        int height;
   
        (width, height) = Lib2D.getWidthHeight(fctx.figure.bbox);

        Utils.concat(buffer, '<symbol ');
        Utils.concat(buffer,
            bytes(Svg.prop("id", fctx.id)),
            bytes(Svg.prop("width", Utils.toString(width))),
            bytes(Svg.prop("height", Utils.toString(height))),
            bytes(Svg.prop("viewBox", string.concat(Utils.toString(fctx.figure.bbox.p1.x), ' ', Utils.toString(fctx.figure.bbox.p1.y), ' ', Utils.toString(width), ' ', Utils.toString(height))))
        );
        Utils.concat(buffer, '>');

        Gradients.createAllFigureGradients(buffer, fctx.id, fctx.color);
        //Utils.concat(buffer, bytes(Filters.createDropShadowFilter()));


        createAllPathNodes(buffer, AllPathNodesCtx(fctx.id, string(fctx.figure.id), savedPathId, fctx.figure.bbox, savedBBox, fctx.color, fctx.wrapType, fctx.figure.offsetY, fctx.figure.padding, fctx.figure.percentIncrease));

        Utils.concat(buffer, '</symbol>');
    }

    function createAllPathNodes(bytes memory buffer, AllPathNodesCtx memory ctx) private pure {
        string memory strokeWidth;
        string memory resizePercentage;
        string memory resizePercentage2;

        (strokeWidth, resizePercentage, resizePercentage2) = calculateStrokeWidthAndResizePercentages(ctx.wrapType != WrapType.NONE ? ctx.bb : ctx.savedBBox);

        createPathNodeMain(buffer, ctx.id, ctx.pathId, resizePercentage, strokeWidth);
        createPathNodeSecond(buffer, ctx.id, ctx.pathId, resizePercentage2);
        createWrapNode(buffer, ctx);
    }

    function calculateStrokeWidth(BoundingBox memory bb) public pure returns (int) {
        int width;
        int height;

        (width, height) = Lib2D.getWidthHeight(bb);

        int size = width;
        if (height > width) size = height;

        return size * Utils.MULTIPLIER / 25;
    }

    function calculateStrokeWidthAndResizePercentages(BoundingBox memory bb) private pure returns (string memory strokeWidth, string memory resizePercentage, string memory resizePercentage2) {
        int width;
        int height;

        (width, height) = Lib2D.getWidthHeight(bb);

        int size = width;
        if (height > width) size = height;

        int strokeWidthInt = calculateStrokeWidth(bb);
        int resizePercentageInt = (size * Utils.MULTIPLIER - strokeWidthInt * 2) / size;
        int resizePercentage2Int = resizePercentageInt * 100 / 101;

        strokeWidth = Division.divisionStr(3, strokeWidthInt, Utils.MULTIPLIER);
        resizePercentage = Division.divisionStr(3, resizePercentageInt, Utils.MULTIPLIER);
        resizePercentage2 = Division.divisionStr(3, resizePercentage2Int, Utils.MULTIPLIER);
    }

    function createPathNodeMain(bytes memory buffer, string memory id, string memory pathId, string memory resizePercentage, string memory strokeWidth) private pure {
        Utils.concat(buffer, '<g style="transform-origin: center; transform-box: fill-box;"');
        Utils.concat(buffer, " transform='scale(", bytes(resizePercentage), ")'");
        Utils.concat(buffer, " fill='url(#",bytes(id),"-fillgr)'");
        Utils.concat(buffer, " stroke='url(#",bytes(id),"-strokegr)'");
        Utils.concat(buffer, " stroke-width='", bytes(strokeWidth), "'");
        Utils.concat(buffer, ">");
        Utils.concat(buffer, '<use href="#', bytes(pathId), '" />');
        Utils.concat(buffer, '</g>');
    }

    function createPathNodeSecond(bytes memory buffer, string memory id, string memory pathId, string memory resizePercentage2) private pure {
        Utils.concat(buffer, '<g style="transform-origin: center; transform-box: fill-box; "');
        Utils.concat(buffer, " transform='scale(", bytes(resizePercentage2), ")'");
        Utils.concat(buffer, " opacity='0.4'");
        Utils.concat(buffer, " fill='url(#",bytes(id),"-overgr)'");
        Utils.concat(buffer, " stroke-width='0'");
        Utils.concat(buffer, ">");
        Utils.concat(buffer, '<use href="#', bytes(pathId), '" />');
        Utils.concat(buffer, '</g>');
    }

    // function createPathMaskNode(string memory id, string memory path, string memory resizePercentage, string memory strokeWidth) private pure returns (string memory) {
    //     string memory g = Svg.g(
    //         string.concat(
    //             //Svg.prop("d", path),
    //             'style="transform-origin: center; transform-box: fill-box;"',
    //             Svg.prop("transform", string.concat('scale(', resizePercentage, ')')),
    //             Svg.prop("fill", "white"),
    //             Svg.prop("stroke", "white"),
    //             Svg.prop("opacity", "0.6"),
    //             Svg.prop("stroke-width", strokeWidth)
    //         ), path);
        
    //     return Svg.mask(
    //         Svg.prop("id", string.concat(id, "-cp")),
    //         g
    //     );
    // }

    // function createCircleMaskNode(string memory id, Lib2D.BoundingBox memory bb) private pure returns (string memory) {
    //     int width;
    //     int height;

    //     (width, height) = Lib2D.getWidthHeight(bb);

    //     int cx = bb.p1.x * Utils.MULTIPLIER + width * Utils.MULTIPLIER / 2;
    //     int cy = bb.p1.y * Utils.MULTIPLIER - height * Utils.MULTIPLIER * 100 / 145;
    //     int r = height * Utils.MULTIPLIER * 100 / 77;

    //     return Svg.circle(
    //         string.concat(
    //             Svg.prop("cx", Division.divisionStr(2, cx, Utils.MULTIPLIER)),
    //             Svg.prop("cy", Division.divisionStr(2, cy, Utils.MULTIPLIER)),
    //             Svg.prop("r", Division.divisionStr(2, r, Utils.MULTIPLIER)),
    //             Svg.prop("fill", string.concat('url(#',id,'-gr3)')),
    //             Svg.prop("style", string.concat('mask: url(#',id,'-cp)'))
    //         ), "");
    // }

    function createWrapNode(bytes memory buffer, AllPathNodesCtx memory ctx) private pure {        
        if (ctx.wrapType == WrapType.NONE) {
            return;
        }
        
        Point memory point;
        int newWidth;
        int newHeight;

        int offset = 900;
        int yOffset = 0;

        int percentIncrease = ctx.percentIncrease * 10;

        if (ctx.wrapType == WrapType.SQUARE) {
            offset = 400;
        } else if (ctx.wrapType == WrapType.SQUARE_45) {
            offset = 800 + ctx.padding;
            yOffset = ctx.offsetY;
            percentIncrease = percentIncrease * 100 / 110;
        } else if (ctx.wrapType == WrapType.HEXAGON) {
            offset = 650 + ctx.padding;
            yOffset = ctx.offsetY;
            
        } else if (ctx.wrapType == WrapType.HEXAGON_30) {
            offset = 650 + ctx.padding/2;
            yOffset = ctx.offsetY/2;
            
        } else if (ctx.wrapType == WrapType.CIRCLE) {
            offset = 800 + ctx.padding*2/3;
            yOffset = ctx.offsetY;
        }

        ctx.savedBBox = Lib2D.scaleBoundingBox(ctx.savedBBox, percentIncrease);
        (point, newWidth, newHeight) = Lib2D.centerBBoxInBBox(ctx.bb, ctx.savedBBox, offset);
        point.y += yOffset;

    
        Utils.concat(buffer, '<g filter="url(#drop-shadow)">');
            Utils.concat(buffer, '<svg ', bytes(heightWidthViewBox(point, ctx.savedBBox, newWidth, newHeight)), '>');
                Utils.concat(buffer, '<g fill="url(#',bytes(ctx.id),'-innergr)">');
                    //Utils.concat(buffer, bytes(ctx.savedPath));
                     Utils.concat(buffer, '<use href="#', bytes(ctx.savedPathId), '" />');
                Utils.concat(buffer, '</g>');
        Utils.concat(buffer, '</svg>');
        Utils.concat(buffer, '</g>');
    }

    function heightWidthViewBox(Point memory point, BoundingBox memory bb, int newWidth, int newHeight) private pure returns (string memory) {
        int width;
        int height;

        (width, height) = Lib2D.getWidthHeight(bb);

        return string.concat(
            Svg.prop("x", Utils.toString(point.x)),
            Svg.prop("y", Utils.toString(point.y)),
            Svg.prop("width", Utils.toString(newWidth)),
            Svg.prop("height", Utils.toString(newHeight)),
            Svg.prop("viewBox",
                string.concat(Utils.toString(bb.p1.x), ' ', Utils.toString(bb.p1.y), ' ', Utils.toString(width), ' ', Utils.toString(height))
            )
        );
    }
}